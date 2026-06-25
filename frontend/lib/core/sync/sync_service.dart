import '../../features/nurse/data/local/nurse_local_dao.dart';
import '../../features/nurse/domain/patient.dart';
import '../api/api_client.dart';
import '../notifications/notification_local_dao.dart';
import '../notifications/notification_models.dart';
import '../offline/offline_models.dart';
import 'sync_outbox_dao.dart';

class SyncDependencyPending implements Exception {
  const SyncDependencyPending(this.message);

  final String message;

  @override
  String toString() => message;
}

/// La dépendance (ex. patient parent) a échoué de façon permanente :
/// inutile de réessayer, l'entrée dépendante doit basculer en échec.
class SyncDependencyFailed implements Exception {
  const SyncDependencyFailed(this.message);

  final String message;

  @override
  String toString() => message;
}

class SyncRunSummary {
  const SyncRunSummary({
    required this.processed,
    required this.synced,
    required this.failed,
    required this.pending,
  });

  final int processed;
  final int synced;
  final int failed;
  final int pending;
}

class SyncService {
  SyncService({
    required ApiClient apiClient,
    SyncOutboxDao? outboxDao,
    NurseLocalDao? nurseLocalDao,
    NotificationLocalDao? notificationDao,
  })  : _apiClient = apiClient,
        _outboxDao = outboxDao ?? SyncOutboxDao.instance,
        _nurseLocalDao = nurseLocalDao ?? NurseLocalDao.instance,
        _notificationDao = notificationDao ?? NotificationLocalDao.instance;

  final ApiClient _apiClient;
  final SyncOutboxDao _outboxDao;
  final NurseLocalDao _nurseLocalDao;
  final NotificationLocalDao _notificationDao;

  /// Garde anti-concurrence : empêche deux passes de sync simultanées
  /// (déclenchées par la connectivité, le timer et le retry manuel) de traiter
  /// les mêmes entrées et de provoquer des doubles envois.
  bool _running = false;

  Future<SyncRunSummary> synchronizePending({int limit = 20}) async {
    if (_running) {
      return SyncRunSummary(
        processed: 0,
        synced: 0,
        failed: 0,
        pending: await _outboxDao.countPending(),
      );
    }
    _running = true;
    try {
      return await _runPending(limit: limit);
    } finally {
      _running = false;
    }
  }

  Future<SyncRunSummary> _runPending({required int limit}) async {
    final entries = await _outboxDao.listRunnable(limit: limit);
    var synced = 0;
    var failed = 0;

    for (final entry in entries) {
      try {
        final didSync = await _processEntry(entry);
        if (didSync) synced++;
      } on SyncDependencyFailed catch (error) {
        await _markPermanentFailure(entry, error);
        failed++;
      } on SyncDependencyPending catch (error) {
        if (await _retryOrDeadLetter(entry, error)) failed++;
      } on ApiException catch (error) {
        if (error.isAuthFailure) rethrow;
        if (error.isPermanentClientFailure && !error.isNetworkFailure) {
          await _markPermanentFailure(entry, error);
          failed++;
        } else {
          if (await _retryOrDeadLetter(entry, error)) failed++;
        }
      } catch (error) {
        if (await _retryOrDeadLetter(entry, error)) failed++;
      }
    }

    return SyncRunSummary(
      processed: entries.length,
      synced: synced,
      failed: failed,
      pending: await _outboxDao.countPending(),
    );
  }

  /// Replanifie l'entrée ; si elle bascule en dead-letter (trop de tentatives),
  /// marque aussi l'entité métier en échec + notifie. Retourne `true` dans ce cas.
  Future<bool> _retryOrDeadLetter(SyncOutboxEntry entry, Object error) async {
    final deadLettered = await _outboxDao.markRetryableFailure(entry, error);
    if (deadLettered) {
      await _markPermanentFailure(entry, error);
    }
    return deadLettered;
  }

  Future<bool> _processEntry(SyncOutboxEntry entry) async {
    if (entry.operation == OutboxOperation.createPatient.value) {
      await _syncPatient(entry);
      return true;
    }

    if (entry.operation == OutboxOperation.submitDiagnosis.value) {
      await _syncDiagnosis(entry);
      return true;
    }

    await _outboxDao.markFailed(
      entry.localId,
      'Operation de synchronisation non supportee: ${entry.operation}',
    );
    return false;
  }

  Future<void> _syncPatient(SyncOutboxEntry entry) async {
    final response = await _apiClient.postJson('/patients', entry.payload);
    final patient =
        Patient.fromJson(response['patient'] as Map<String, dynamic>);

    await _nurseLocalDao.markPatientSynced(
      localId: entry.entityLocalId,
      remotePatient: patient,
    );
    await _outboxDao.markSynced(entry.localId);
  }

  Future<void> _syncDiagnosis(SyncOutboxEntry entry) async {
    final record =
        await _nurseLocalDao.getDiagnosisSyncRecord(entry.entityLocalId);
    if (record == null) {
      await _outboxDao.markFailed(
        entry.localId,
        'Consultation locale introuvable',
      );
      return;
    }

    if (!record.canSync) {
      // Le patient parent n'a pas encore d'identifiant serveur. Si sa propre
      // synchronisation a échoué de façon permanente, la consultation ne pourra
      // jamais partir : on la fait échouer en cascade plutôt que boucler.
      final localPatientId = entry.payload['localPatientId']?.toString();
      if (localPatientId != null) {
        final patientStatus =
            await _nurseLocalDao.patientSyncStatus(localPatientId);
        if (patientStatus == SyncStatus.syncFailed) {
          throw const SyncDependencyFailed(
            'Le patient associe a echoue : consultation non synchronisable',
          );
        }
      }
      throw const SyncDependencyPending(
        'Patient serveur indisponible pour cette consultation',
      );
    }

    final image = record.image;
    final Map<String, dynamic> response;
    if (image != null) {
      response = await _apiClient.postMultipartBytes(
        path: '/cases/diagnose',
        fileField: 'file',
        bytes: image.bytes,
        fileName: image.fileName,
        mimeType: image.mimeType,
        fields: record.toMultipartFields(),
      );
    } else {
      response = await _apiClient.postJson(
        '/cases/diagnose',
        record.toJsonBody(),
      );
    }

    final caseJson = response['case'] as Map<String, dynamic>;
    await _nurseLocalDao.markDiagnosisSynced(
      consultationLocalId: entry.entityLocalId,
      remoteCaseJson: caseJson,
    );
    await _outboxDao.markSynced(entry.localId);

    await _notificationDao.insertLocal(
      type: NotificationType.syncCompleted,
      title: 'Consultation synchronisée',
      body: 'Une consultation enregistrée hors-ligne a été synchronisée.',
      consultationId: caseJson['id']?.toString(),
    );
  }

  Future<void> _markPermanentFailure(
    SyncOutboxEntry entry,
    Object error,
  ) async {
    if (entry.operation == OutboxOperation.createPatient.value) {
      await _nurseLocalDao.markPatientSyncFailed(
        localId: entry.entityLocalId,
        error: error,
      );
      return;
    }

    if (entry.operation == OutboxOperation.submitDiagnosis.value) {
      await _nurseLocalDao.markDiagnosisFailed(
        consultationLocalId: entry.entityLocalId,
        error: error,
      );
      await _notificationDao.insertLocal(
        type: NotificationType.syncFailed,
        title: 'Échec de synchronisation',
        body:
            "Une consultation n'a pas pu être synchronisée. Voir les éléments en échec.",
      );
      return;
    }

    await _outboxDao.markFailed(entry.localId, error);
  }
}
