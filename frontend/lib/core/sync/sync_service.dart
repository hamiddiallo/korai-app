import '../../features/nurse/data/local/nurse_local_dao.dart';
import '../../features/nurse/domain/patient.dart';
import '../api/api_client.dart';
import '../offline/offline_models.dart';
import 'sync_outbox_dao.dart';

class SyncDependencyPending implements Exception {
  const SyncDependencyPending(this.message);

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
  })  : _apiClient = apiClient,
        _outboxDao = outboxDao ?? SyncOutboxDao.instance,
        _nurseLocalDao = nurseLocalDao ?? NurseLocalDao.instance;

  final ApiClient _apiClient;
  final SyncOutboxDao _outboxDao;
  final NurseLocalDao _nurseLocalDao;

  Future<SyncRunSummary> synchronizePending({int limit = 20}) async {
    final entries = await _outboxDao.listRunnable(limit: limit);
    var synced = 0;
    var failed = 0;

    for (final entry in entries) {
      try {
        final didSync = await _processEntry(entry);
        if (didSync) synced++;
      } on SyncDependencyPending catch (error) {
        await _outboxDao.markRetryableFailure(entry, error);
      } on ApiException catch (error) {
        if (error.isAuthFailure) rethrow;
        if (error.isPermanentClientFailure) {
          await _markPermanentFailure(entry, error);
          failed++;
        } else {
          await _outboxDao.markRetryableFailure(entry, error);
        }
      } catch (error) {
        await _outboxDao.markRetryableFailure(entry, error);
      }
    }

    return SyncRunSummary(
      processed: entries.length,
      synced: synced,
      failed: failed,
      pending: await _outboxDao.countPending(),
    );
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

    await _nurseLocalDao.markDiagnosisSynced(
      consultationLocalId: entry.entityLocalId,
      remoteCaseJson: response['case'] as Map<String, dynamic>,
    );
    await _outboxDao.markSynced(entry.localId);
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
      return;
    }

    await _outboxDao.markFailed(entry.localId, error);
  }
}
