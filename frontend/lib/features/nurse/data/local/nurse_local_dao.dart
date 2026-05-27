import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/domain/consultation_create_payload.dart';
import '../../../../core/offline/offline_models.dart';
import '../../../../core/storage/encrypted_local_database.dart';
import '../../../../core/sync/sync_outbox_dao.dart';
import '../../domain/patient.dart';

class LocalConsultationDraft {
  const LocalConsultationDraft({
    required this.localId,
    this.imageLocalId,
  });

  final String localId;
  final String? imageLocalId;
}

class LocalOtoscopicImageSyncRecord {
  const LocalOtoscopicImageSyncRecord({
    required this.localId,
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  final String localId;
  final Uint8List bytes;
  final String mimeType;
  final String fileName;
}

class LocalDiagnosisSyncRecord {
  const LocalDiagnosisSyncRecord({
    required this.localId,
    required this.serverPatientId,
    required this.clinicalNarrative,
    required this.clinicalNotes,
    required this.urgency,
    required this.earSide,
    required this.showSources,
    required this.requestSpecialistReview,
    required this.symptomIds,
    required this.symptomLabels,
    required this.medicalHistoryIds,
    required this.medicalHistoryLabels,
    required this.touchCheckIds,
    required this.touchCheckLabels,
    required this.touchObservations,
    this.image,
  });

  final String localId;
  final String? serverPatientId;
  final String clinicalNarrative;
  final String? clinicalNotes;
  final String urgency;
  final String earSide;
  final bool showSources;
  final bool requestSpecialistReview;
  final List<String> symptomIds;
  final List<String> symptomLabels;
  final List<String> medicalHistoryIds;
  final List<String> medicalHistoryLabels;
  final List<String> touchCheckIds;
  final List<String> touchCheckLabels;
  final Map<String, String> touchObservations;
  final LocalOtoscopicImageSyncRecord? image;

  bool get canSync => serverPatientId != null && serverPatientId!.isNotEmpty;

  Map<String, dynamic> toJsonBody() => {
        'patientId': serverPatientId,
        'symptoms': clinicalNarrative,
        if (clinicalNotes != null && clinicalNotes!.isNotEmpty)
          'clinicalNotes': clinicalNotes,
        'urgency': urgency,
        'earSide': earSide,
        'showSources': showSources,
        'requestSpecialistReview': requestSpecialistReview,
        if (symptomIds.isNotEmpty) 'symptomIds': symptomIds,
        if (symptomLabels.isNotEmpty) 'symptomLabels': symptomLabels,
        if (medicalHistoryIds.isNotEmpty)
          'medicalHistoryIds': medicalHistoryIds,
        if (medicalHistoryLabels.isNotEmpty)
          'medicalHistoryLabels': medicalHistoryLabels,
        if (touchCheckIds.isNotEmpty) 'touchCheckIds': touchCheckIds,
        if (touchCheckLabels.isNotEmpty) 'touchCheckLabels': touchCheckLabels,
        if (touchObservations.isNotEmpty)
          'touchObservations': touchObservations,
        'clientLocalId': localId,
      };

  Map<String, String> toMultipartFields() => {
        'patientId': serverPatientId ?? '',
        'symptoms': clinicalNarrative,
        if (clinicalNotes != null && clinicalNotes!.isNotEmpty)
          'clinicalNotes': clinicalNotes!,
        'urgency': urgency,
        'earSide': earSide,
        'showSources': showSources.toString(),
        'requestSpecialistReview': requestSpecialistReview.toString(),
        if (symptomIds.isNotEmpty) 'symptomIds': jsonEncode(symptomIds),
        if (symptomLabels.isNotEmpty)
          'symptomLabels': jsonEncode(symptomLabels),
        if (medicalHistoryIds.isNotEmpty)
          'medicalHistoryIds': jsonEncode(medicalHistoryIds),
        if (medicalHistoryLabels.isNotEmpty)
          'medicalHistoryLabels': jsonEncode(medicalHistoryLabels),
        if (touchCheckIds.isNotEmpty)
          'touchCheckIds': jsonEncode(touchCheckIds),
        if (touchCheckLabels.isNotEmpty)
          'touchCheckLabels': jsonEncode(touchCheckLabels),
        if (touchObservations.isNotEmpty)
          'touchObservations': jsonEncode(touchObservations),
        'clientLocalId': localId,
      };
}

class NurseLocalDao {
  NurseLocalDao({
    EncryptedLocalDatabase? database,
    SyncOutboxDao? outboxDao,
  })  : _database = database ?? EncryptedLocalDatabase.instance,
        _outboxDao = outboxDao ?? SyncOutboxDao.instance;

  static final NurseLocalDao instance = NurseLocalDao();
  static const localIdPrefix = 'local_';

  final EncryptedLocalDatabase _database;
  final SyncOutboxDao _outboxDao;
  final _uuid = const Uuid();

  static bool isLocalId(String id) => id.startsWith(localIdPrefix);

  Future<Patient> savePatientDraft({
    String? localId,
    required String firstName,
    required String lastName,
    String? birthDate,
    String? phone,
    String? sex,
    String? address,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = localId ?? '$localIdPrefix${_uuid.v4()}';

    await db.insert(
      'local_patients',
      {
        'local_id': id,
        'first_name': firstName,
        'last_name': lastName,
        'phone': _blankToNull(phone),
        'address': _blankToNull(address),
        'birth_date': _blankToNull(birthDate),
        'sex': _blankToNull(sex),
        'consent_for_ai': 1,
        'consent_for_tele_expertise': 1,
        'is_validated': 0,
        'sync_status': SyncStatus.pendingSync.value,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _outboxDao.enqueue(
      entityType: OfflineEntityType.patient,
      entityLocalId: id,
      operation: OutboxOperation.createPatient,
      payload: {
        'clientLocalId': id,
        'firstName': firstName,
        'lastName': lastName,
        if (birthDate != null && birthDate.isNotEmpty) 'birthDate': birthDate,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (sex != null && sex.isNotEmpty) 'sex': sex,
        if (address != null && address.isNotEmpty) 'address': address,
        'consentForAi': true,
        'consentForTeleExpertise': true,
      },
      priority: 10,
    );

    return Patient(
      id: id,
      firstName: firstName,
      lastName: lastName,
      phone: _blankToNull(phone),
      address: _blankToNull(address),
      birthDate: _blankToNull(birthDate),
      sex: _blankToNull(sex),
      isValidated: false,
    );
  }

  Future<void> cacheRemotePatients(List<Patient> patients) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      for (final patient in patients) {
        final existing = await txn.query(
          'local_patients',
          columns: ['local_id'],
          where: 'server_id = ?',
          whereArgs: [patient.id],
          limit: 1,
        );
        final row = {
          'server_id': patient.id,
          'first_name': patient.firstName,
          'last_name': patient.lastName,
          'phone': patient.phone,
          'address': patient.address,
          'birth_date': patient.birthDate,
          'sex': patient.sex,
          'consent_for_ai': 1,
          'consent_for_tele_expertise': 1,
          'is_validated': patient.isValidated ? 1 : 0,
          'sync_status': SyncStatus.synced.value,
          'last_sync_error': null,
          'updated_at': now,
        };

        if (existing.isNotEmpty) {
          await txn.update(
            'local_patients',
            row,
            where: 'local_id = ?',
            whereArgs: [existing.first['local_id'].toString()],
          );
        } else {
          await txn.insert(
            'local_patients',
            {
              ...row,
              'local_id': patient.id,
              'created_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
  }

  Future<List<Patient>> listPatients() async {
    final db = await _database.database;
    final rows = await db.query(
      'local_patients',
      orderBy: 'updated_at DESC',
    );
    return rows.map(_patientFromRow).toList();
  }

  Future<void> markPatientSynced({
    required String localId,
    required Patient remotePatient,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'local_patients',
        where: 'server_id = ? AND local_id <> ?',
        whereArgs: [remotePatient.id, localId],
      );
      await txn.update(
        'local_patients',
        {
          'server_id': remotePatient.id,
          'first_name': remotePatient.firstName,
          'last_name': remotePatient.lastName,
          'phone': remotePatient.phone,
          'address': remotePatient.address,
          'birth_date': remotePatient.birthDate,
          'sex': remotePatient.sex,
          'is_validated': remotePatient.isValidated ? 1 : 0,
          'sync_status': SyncStatus.synced.value,
          'last_sync_error': null,
          'updated_at': now,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
      await txn.update(
        'local_consultations',
        {
          'server_patient_id': remotePatient.id,
          'updated_at': now,
        },
        where: 'local_patient_id = ?',
        whereArgs: [localId],
      );
    });
    await _outboxDao.markSyncedByEntity(
      entityType: OfflineEntityType.patient,
      entityLocalId: localId,
    );
  }

  Future<void> markPatientSyncFailed({
    required String localId,
    required Object error,
  }) async {
    final db = await _database.database;
    await db.update(
      'local_patients',
      {
        'sync_status': SyncStatus.syncFailed.value,
        'last_sync_error': error.toString(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
    await _outboxDao.markFailedByEntity(
      entityType: OfflineEntityType.patient,
      entityLocalId: localId,
      error: error,
    );
  }

  Future<LocalConsultationDraft> savePendingDiagnosisDraft({
    required Patient patient,
    required ConsultationCreatePayload payload,
    File? image,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final localPatientId = await _resolveLocalPatientId(patient);
    final consultationId = '$localIdPrefix${_uuid.v4()}';
    final imageId = image == null ? null : '$localIdPrefix${_uuid.v4()}';

    await db.transaction((txn) async {
      await txn.insert(
        'local_consultations',
        {
          'local_id': consultationId,
          'local_patient_id': localPatientId,
          'server_patient_id': isLocalId(patient.id) ? null : patient.id,
          'clinical_narrative': payload.symptoms,
          'clinical_notes': payload.clinicalNotes,
          'urgency': payload.urgency.value,
          'ear_side': payload.earSide.value,
          'show_sources': payload.showSources ? 1 : 0,
          'request_specialist_review': payload.requestSpecialistReview ? 1 : 0,
          'symptom_ids_json': jsonEncode(payload.symptomIds),
          'symptom_labels_json': jsonEncode(payload.symptomLabels),
          'medical_history_ids_json': jsonEncode(payload.medicalHistoryIds),
          'medical_history_labels_json':
              jsonEncode(payload.medicalHistoryLabels),
          'touch_check_ids_json': jsonEncode(payload.touchCheckIds),
          'touch_check_labels_json': jsonEncode(payload.touchCheckLabels),
          'touch_observations_json': jsonEncode(payload.touchObservations),
          'status': 'PENDING_AI',
          'sync_status': SyncStatus.pendingSync.value,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (image != null && imageId != null) {
        final bytes = await image.readAsBytes();
        await txn.insert(
          'local_otoscopic_images',
          {
            'local_id': imageId,
            'local_consultation_id': consultationId,
            'ear_side': payload.earSide.value,
            'mime_type': 'image/jpeg',
            'file_name': p.basename(image.path),
            'bytes': bytes,
            'byte_size': bytes.length,
            'sync_status': SyncStatus.pendingSync.value,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    await _outboxDao.enqueue(
      entityType: OfflineEntityType.consultation,
      entityLocalId: consultationId,
      operation: OutboxOperation.submitDiagnosis,
      payload: {
        'clientLocalId': consultationId,
        'localPatientId': localPatientId,
        if (!isLocalId(patient.id)) 'serverPatientId': patient.id,
        'diagnosisPayload': payload.toJsonBody(),
        if (imageId != null) 'imageLocalId': imageId,
      },
      priority: 20,
    );

    return LocalConsultationDraft(
      localId: consultationId,
      imageLocalId: imageId,
    );
  }

  Future<void> markDiagnosisSynced({
    required String consultationLocalId,
    required Map<String, dynamic> remoteCaseJson,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final remoteCaseId = remoteCaseJson['id']?.toString();
    final summary =
        (remoteCaseJson['organizedAiSummary'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};

    await db.transaction((txn) async {
      await txn.update(
        'local_consultations',
        {
          'server_id': remoteCaseId,
          'status': remoteCaseJson['status']?.toString() ?? 'AI_COMPLETED',
          'sync_status': SyncStatus.synced.value,
          'last_sync_error': null,
          'updated_at': now,
        },
        where: 'local_id = ?',
        whereArgs: [consultationLocalId],
      );

      await txn.update(
        'local_otoscopic_images',
        {
          'server_consultation_id': remoteCaseId,
          'sync_status': SyncStatus.synced.value,
        },
        where: 'local_consultation_id = ?',
        whereArgs: [consultationLocalId],
      );

      await txn.insert(
        'local_ai_responses',
        {
          'local_id': '$localIdPrefix${_uuid.v4()}',
          'local_consultation_id': consultationLocalId,
          'server_consultation_id': remoteCaseId,
          'raw_json': jsonEncode(remoteCaseJson),
          'image_opinion': summary['imageOpinion']?.toString(),
          'rag_opinion': summary['ragOpinion']?.toString(),
          'likely_diagnosis': summary['likelyDiagnosis']?.toString(),
          'confidence_label': summary['confidenceLabel']?.toString(),
          'warnings_json': jsonEncode(summary['warnings'] ?? const []),
          'sources_json': jsonEncode(summary['sources'] ?? const []),
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    await _outboxDao.markSyncedByEntity(
      entityType: OfflineEntityType.consultation,
      entityLocalId: consultationLocalId,
    );
  }

  Future<void> markDiagnosisFailed({
    required String consultationLocalId,
    required Object error,
  }) async {
    final db = await _database.database;
    await db.update(
      'local_consultations',
      {
        'sync_status': SyncStatus.syncFailed.value,
        'last_sync_error': error.toString(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [consultationLocalId],
    );
    await _outboxDao.markFailedByEntity(
      entityType: OfflineEntityType.consultation,
      entityLocalId: consultationLocalId,
      error: error,
    );
  }

  Future<LocalDiagnosisSyncRecord?> getDiagnosisSyncRecord(
    String consultationLocalId,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'local_consultations',
      where: 'local_id = ?',
      whereArgs: [consultationLocalId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final localPatientId = row['local_patient_id'].toString();
    String? serverPatientId = row['server_patient_id']?.toString();

    if (serverPatientId == null || serverPatientId.isEmpty) {
      final patientRows = await db.query(
        'local_patients',
        columns: ['server_id'],
        where: 'local_id = ?',
        whereArgs: [localPatientId],
        limit: 1,
      );
      if (patientRows.isNotEmpty) {
        serverPatientId = patientRows.first['server_id']?.toString();
      }
    }

    final imageRows = await db.query(
      'local_otoscopic_images',
      where: 'local_consultation_id = ?',
      whereArgs: [consultationLocalId],
      limit: 1,
    );
    final image = imageRows.isEmpty
        ? null
        : LocalOtoscopicImageSyncRecord(
            localId: imageRows.first['local_id'].toString(),
            bytes: imageRows.first['bytes'] as Uint8List,
            mimeType: imageRows.first['mime_type']?.toString() ?? 'image/jpeg',
            fileName:
                imageRows.first['file_name']?.toString() ?? 'otoscopie.jpg',
          );

    return LocalDiagnosisSyncRecord(
      localId: consultationLocalId,
      serverPatientId: serverPatientId,
      clinicalNarrative: row['clinical_narrative'].toString(),
      clinicalNotes: row['clinical_notes']?.toString(),
      urgency: row['urgency'].toString(),
      earSide: row['ear_side'].toString(),
      showSources: row['show_sources'] == 1,
      requestSpecialistReview: row['request_specialist_review'] == 1,
      symptomIds: _decodeStringList(row['symptom_ids_json']),
      symptomLabels: _decodeStringList(row['symptom_labels_json']),
      medicalHistoryIds: _decodeStringList(row['medical_history_ids_json']),
      medicalHistoryLabels:
          _decodeStringList(row['medical_history_labels_json']),
      touchCheckIds: _decodeStringList(row['touch_check_ids_json']),
      touchCheckLabels: _decodeStringList(row['touch_check_labels_json']),
      touchObservations: _decodeStringMap(row['touch_observations_json']),
      image: image,
    );
  }

  Future<String> _resolveLocalPatientId(Patient patient) async {
    if (isLocalId(patient.id)) return patient.id;

    final db = await _database.database;
    final existing = await db.query(
      'local_patients',
      columns: ['local_id'],
      where: 'server_id = ? OR local_id = ?',
      whereArgs: [patient.id, patient.id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return existing.first['local_id'].toString();
    }

    await cacheRemotePatients([patient]);
    return patient.id;
  }

  Patient _patientFromRow(Map<String, dynamic> row) {
    return Patient(
      id: row['server_id']?.toString() ?? row['local_id'].toString(),
      firstName: row['first_name'].toString(),
      lastName: row['last_name'].toString(),
      phone: row['phone']?.toString(),
      address: row['address']?.toString(),
      birthDate: row['birth_date']?.toString(),
      sex: row['sex']?.toString(),
      isValidated: row['is_validated'] == 1,
    );
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  List<String> _decodeStringList(Object? value) {
    if (value == null) return const [];
    final decoded = jsonDecode(value.toString());
    if (decoded is List) return decoded.map((item) => item.toString()).toList();
    return const [];
  }

  Map<String, String> _decodeStringMap(Object? value) {
    if (value == null) return const {};
    final decoded = jsonDecode(value.toString());
    if (decoded is Map) {
      return decoded.map(
        (key, val) => MapEntry(key.toString(), val.toString()),
      );
    }
    return const {};
  }
}
