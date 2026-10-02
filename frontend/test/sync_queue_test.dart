import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:korai_frontend/core/api/api_client.dart';
import 'package:korai_frontend/core/notifications/notification_local_dao.dart';
import 'package:korai_frontend/core/notifications/notification_models.dart';
import 'package:korai_frontend/core/offline/offline_models.dart';
import 'package:korai_frontend/core/sync/sync_outbox_dao.dart';
import 'package:korai_frontend/core/sync/sync_service.dart';
import 'package:korai_frontend/features/nurse/data/local/nurse_local_dao.dart';

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

SyncOutboxEntry _entry(String id) => SyncOutboxEntry(
      localId: 'outbox-$id',
      entityType: OfflineEntityType.consultation.value,
      entityLocalId: id,
      operation: OutboxOperation.submitDiagnosis.value,
      payload: const {},
      status: SyncStatus.pendingSync,
      attemptCount: 0,
    );

/// File d'envoi en mémoire : enregistre ce que le service en fait.
class _FakeOutbox extends SyncOutboxDao {
  _FakeOutbox(this.entries);

  final List<SyncOutboxEntry> entries;
  final waitingForNetwork = <String>[];
  final retried = <String>[];
  final synced = <String>[];

  @override
  Future<int> purgeSynced({Duration olderThan = const Duration(days: 7)}) async => 0;
  @override
  Future<List<SyncOutboxEntry>> listRunnable({int limit = 25}) async => entries;
  @override
  Future<int> countPending() async => 0;
  @override
  Future<void> markWaitingForNetwork(SyncOutboxEntry entry, Object error) async =>
      waitingForNetwork.add(entry.entityLocalId);
  @override
  Future<bool> markRetryableFailure(SyncOutboxEntry entry, Object error) async {
    retried.add(entry.entityLocalId);
    return false;
  }

  @override
  Future<void> markSynced(String localId) async => synced.add(localId);
}

class _FakeLocal extends NurseLocalDao {
  final failed = <String, String>{};
  final sent = <String>[];

  @override
  Future<LocalDiagnosisSyncRecord?> getDiagnosisSyncRecord(String consultationLocalId) async =>
      LocalDiagnosisSyncRecord(
        localId: consultationLocalId,
        serverPatientId: 'patient-$consultationLocalId',
        clinicalNarrative: 'Otalgie',
        clinicalNotes: null,
        urgency: 'LOW',
        earSide: 'LEFT',
        showSources: true,
        requestSpecialistReview: false,
        symptomIds: const [],
        symptomLabels: const [],
        medicalHistoryIds: const [],
        medicalHistoryLabels: const [],
        touchCheckIds: const [],
        touchCheckLabels: const [],
        touchObservations: const {},
      );

  @override
  Future<void> markDiagnosisSynced({
    required String consultationLocalId,
    required Map<String, dynamic> remoteCaseJson,
  }) async =>
      sent.add(consultationLocalId);

  @override
  Future<void> markDiagnosisFailed({required String consultationLocalId, required Object error}) async =>
      failed[consultationLocalId] = error.toString();
}

class _FakeNotifications extends NotificationLocalDao {
  @override
  Future<void> insertLocal({
    required NotificationType type,
    required String title,
    required String body,
    String? consultationId,
    String? patientId,
  }) async {}
}

void main() {
  late _FakeLocal local;

  SyncService serviceFor(_FakeOutbox outbox, http.Response Function(String patientId) respond) {
    local = _FakeLocal();
    final api = ApiClient(
      httpClient: MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        return respond(body['patientId'].toString());
      }),
    );
    return SyncService(apiClient: api, outboxDao: outbox, nurseLocalDao: local, notificationDao: _FakeNotifications());
  }

  test('un refus 403 ne bloque plus la file : les consultations suivantes partent', () async {
    final outbox = _FakeOutbox([_entry('a'), _entry('b')]);
    final service = serviceFor(outbox, (patientId) {
      if (patientId == 'patient-a') {
        return _json(403, {
          'error': {'code': 'CONSENT_AI_REQUIRED', 'message': 'Le patient n’a pas donné son accord pour l’IA.'},
        });
      }
      return _json(201, {
        'case': {'id': 'case-b', 'status': 'AI_COMPLETED'},
      });
    });

    final summary = await service.synchronizePending();
    expect(local.failed.keys, ['a'], reason: 'seule la consultation refusée passe en échec');
    expect(local.failed['a'], contains('accord'));
    expect(local.sent, ['b']);
    expect(summary.failed, 1);
  });

  test('une coupure réseau ne consomme pas de tentative', () async {
    final outbox = _FakeOutbox([_entry('a')]);
    local = _FakeLocal();
    final api = ApiClient(httpClient: MockClient((_) async => throw http.ClientException('hors ligne')));
    final service =
        SyncService(apiClient: api, outboxDao: outbox, nurseLocalDao: local, notificationDao: _FakeNotifications());

    await service.synchronizePending();
    expect(outbox.waitingForNetwork, ['a']);
    expect(outbox.retried, isEmpty);
    expect(local.failed, isEmpty);
  });

  test('un envoi déjà reçu (409) est rejoué, jamais marqué en échec', () async {
    final outbox = _FakeOutbox([_entry('a')]);
    final service = serviceFor(
      outbox,
      (_) => _json(409, {
        'error': {'code': 'CONFLICT', 'message': 'Cette ressource existe déjà.'},
      }),
    );
    await service.synchronizePending();
    expect(outbox.retried, ['a']);
    expect(local.failed, isEmpty);
  });

  test('session expirée (401) : la passe s’arrête pour laisser la reconnexion', () async {
    final outbox = _FakeOutbox([_entry('a'), _entry('b')]);
    final service = serviceFor(
      outbox,
      (_) => _json(401, {
        'error': {'code': 'UNAUTHORIZED', 'message': 'Session expirée'},
      }),
    );
    await expectLater(service.synchronizePending(), throwsA(isA<ApiException>()));
    expect(local.failed, isEmpty);
  });

  test('classement des erreurs', () {
    final forbidden = ApiException('refus', code: 'OUT_OF_SCOPE', statusCode: 403);
    expect(forbidden.isAuthFailure, isFalse);
    expect(forbidden.isPermanentClientFailure, isTrue);

    final duplicate = ApiException('déjà reçu', code: 'CONFLICT', statusCode: 409);
    expect(duplicate.isAlreadyReceived, isTrue);
    expect(duplicate.isPermanentClientFailure, isFalse);

    final finished = ApiException('terminée', code: 'EXPERTISE_ALREADY_COMPLETED', statusCode: 409);
    expect(finished.isPermanentClientFailure, isTrue);

    expect(ApiException('expirée', statusCode: 401).isAuthFailure, isTrue);
  });
}
