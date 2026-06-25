import 'dart:convert';
import 'dart:io';

import '../../../core/api/api_client.dart';
import '../../../core/domain/consultation_create_payload.dart';
import '../../../core/storage/clinical_reference_local_dao.dart';
import '../domain/ai_case.dart';
import '../domain/clinical_reference_item.dart';
import '../domain/patient.dart';
import 'local/nurse_local_dao.dart';

class NurseRepository {
  NurseRepository(
    this.apiClient, {
    NurseLocalDao? localDao,
    ClinicalReferenceLocalDao? clinicalReferenceLocalDao,
  })  : _localDao = localDao ?? NurseLocalDao.instance,
        _clinicalReferenceLocalDao =
            clinicalReferenceLocalDao ?? ClinicalReferenceLocalDao.instance;

  final ApiClient apiClient;
  final NurseLocalDao _localDao;
  final ClinicalReferenceLocalDao _clinicalReferenceLocalDao;

  Future<Patient> createPatient({
    required String firstName,
    required String lastName,
    String? birthDate,
    String? phone,
    String? sex,
    String? address,
  }) async {
    final localPatient = await _localDao.savePatientDraft(
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
      phone: phone,
      sex: sex,
      address: address,
    );

    try {
      return await syncLocalPatient(
        localPatient,
        firstName: firstName,
        lastName: lastName,
        birthDate: birthDate,
        phone: phone,
        sex: sex,
        address: address,
      );
    } catch (_) {
      return localPatient;
    }
  }

  Future<Patient> syncLocalPatient(
    Patient patient, {
    required String firstName,
    required String lastName,
    String? birthDate,
    String? phone,
    String? sex,
    String? address,
  }) async {
    if (!NurseLocalDao.isLocalId(patient.id)) return patient;

    final remotePatient = await _createPatientRemote(
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
      phone: phone,
      sex: sex,
      address: address,
      clientLocalId: patient.id,
    );
    await _localDao.markPatientSynced(
      localId: patient.id,
      remotePatient: remotePatient,
    );
    return remotePatient;
  }

  Future<Patient> _createPatientRemote({
    required String firstName,
    required String lastName,
    String? birthDate,
    String? phone,
    String? sex,
    String? address,
    String? clientLocalId,
  }) async {
    final response = await apiClient.postJson('/patients', {
      'firstName': firstName,
      'lastName': lastName,
      if (birthDate != null && birthDate.isNotEmpty) 'birthDate': birthDate,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (sex != null && sex.isNotEmpty) 'sex': sex,
      if (address != null && address.isNotEmpty) 'address': address,
      if (clientLocalId != null && clientLocalId.isNotEmpty)
        'clientLocalId': clientLocalId,
      'consentForAi': true,
      'consentForTeleExpertise': true,
    });
    return Patient.fromJson(response['patient'] as Map<String, dynamic>);
  }

  Future<List<Patient>> listPatients() async {
    try {
      final response = await apiClient.getJson('/patients');
      final remotePatients = (response['patients'] as List<dynamic>)
          .map((p) => Patient.fromJson(p as Map<String, dynamic>))
          .toList();
      await _localDao.cacheRemotePatients(remotePatients);

      final localPatients = await _localDao.listPatients();
      final merged = <String, Patient>{
        for (final patient in remotePatients) patient.id: patient,
      };
      for (final patient in localPatients) {
        merged.putIfAbsent(patient.id, () => patient);
      }
      return merged.values.toList();
    } catch (_) {
      return _localDao.listPatients();
    }
  }

  Future<Patient> validatePatient(String id) async {
    final response = await apiClient.patchJson('/patients/$id', {
      'isValidated': true,
    });
    return Patient.fromJson(response['patient'] as Map<String, dynamic>);
  }

  Future<List<ClinicalReferenceItem>> listClinicalItems(String type) async {
    try {
      final response = await apiClient.getJson('/clinical-items?type=$type');
      final items = (response['items'] as List<dynamic>)
          .map((item) =>
              ClinicalReferenceItem.fromJson(item as Map<String, dynamic>))
          .toList();
      await _clinicalReferenceLocalDao.cacheItems(type, items);
      return items;
    } catch (_) {
      final cached = await _clinicalReferenceLocalDao.listItems(type);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<LocalConsultationDraft> savePendingDiagnosisDraft({
    required Patient patient,
    required ConsultationCreatePayload payload,
    File? image,
  }) {
    return _localDao.savePendingDiagnosisDraft(
      patient: patient,
      payload: payload,
      image: image,
    );
  }

  /// Sans image → backend appelle `/rag/analyze` ; avec image → `/diagnose-separate`.
  Future<AiCase> diagnose({
    required ConsultationCreatePayload payload,
    File? image,
    String? localConsultationId,
  }) async {
    try {
      final Map<String, dynamic> response;
      if (image != null) {
        response = await apiClient.postMultipart(
          path: '/cases/diagnose',
          fileField: 'file',
          file: image,
          fields: {
            ...payload.toMultipartFields(),
            if (localConsultationId != null)
              'clientLocalId': localConsultationId,
          },
        );
      } else {
        response = await apiClient.postJson('/cases/diagnose', {
          ...payload.toJsonBody(),
          if (localConsultationId != null) 'clientLocalId': localConsultationId,
        });
      }
      final caseJson = response['case'] as Map<String, dynamic>;
      if (localConsultationId != null) {
        await _localDao.markDiagnosisSynced(
          consultationLocalId: localConsultationId,
          remoteCaseJson: caseJson,
        );
      }
      return AiCase.fromJson(caseJson);
    } on ApiException catch (error) {
      // Seuls les échecs définitifs (refus serveur 4xx) sont mis en échec.
      // Une panne réseau reste PENDING_SYNC pour être rejouée par l'outbox.
      if (localConsultationId != null &&
          error.isPermanentClientFailure &&
          !error.isNetworkFailure) {
        await _localDao.markDiagnosisFailed(
          consultationLocalId: localConsultationId,
          error: error,
        );
      }
      rethrow;
    }
  }

  /// Relance l'analyse IA d'une consultation en échec (statut AI_FAILED).
  Future<AiCase> retryDiagnosis(String consultationId) async {
    final response =
        await apiClient.postJson('/cases/$consultationId/diagnose/retry', {});
    return AiCase.fromJson(response['case'] as Map<String, dynamic>);
  }

  /// Réutilisation hors-ligne : si le cache local contient une réponse IA pour
  /// une consultation de même empreinte clinique, on l'applique à la nouvelle
  /// consultation et on construit l'AiCase correspondant — sans réseau ni IA.
  /// Retourne `null` si aucune correspondance.
  Future<AiCase?> tryReuseCachedDiagnosis({
    required String localConsultationId,
    required String fingerprint,
    required Patient patient,
    required ConsultationCreatePayload payload,
  }) async {
    final cached = await _localDao.findCachedAiResponseByFingerprint(fingerprint);
    if (cached == null) return null;

    await _localDao.applyReusedAiResponse(
      consultationLocalId: localConsultationId,
      cached: cached,
    );
    return _buildReusedAiCase(localConsultationId, patient, payload, cached);
  }

  AiCase _buildReusedAiCase(
    String localConsultationId,
    Patient patient,
    ConsultationCreatePayload payload,
    LocalCachedAiResponse cached,
  ) {
    const reuseWarning =
        "Réponse IA réutilisée d'une consultation clinique identique (sans nouvelle analyse IA).";

    Map<String, dynamic> caseJson;
    try {
      final decoded = jsonDecode(cached.rawJson);
      caseJson = decoded is Map<String, dynamic>
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      caseJson = <String, dynamic>{};
    }

    final summary = Map<String, dynamic>.from(
      (caseJson['organizedAiSummary'] as Map?) ?? const {},
    );
    final warnings = [...cached.warnings];
    if (!warnings.contains(reuseWarning)) warnings.insert(0, reuseWarning);
    summary['warnings'] = warnings;
    summary['likelyDiagnosis'] ??= cached.likelyDiagnosis;
    summary['imageOpinion'] ??= cached.imageOpinion;
    summary['ragOpinion'] ??= cached.ragOpinion;
    summary['confidenceLabel'] ??= cached.confidenceLabel;
    summary['sources'] ??= cached.sources;

    // Réécrit l'identité pour la NOUVELLE consultation et neutralise les
    // données spécifiques au cas source (expertise, résumé effectif).
    caseJson['organizedAiSummary'] = summary;
    caseJson['id'] = localConsultationId;
    caseJson['patientId'] = patient.id;
    caseJson['status'] = 'AI_COMPLETED';
    caseJson['symptoms'] = payload.symptoms;
    caseJson['earSide'] = payload.earSide.value;
    caseJson.remove('expertiseReview');
    caseJson.remove('effectiveSummary');

    return AiCase.fromJson(caseJson);
  }

  Future<List<AiCase>> listCases() async {
    final response = await apiClient.getJson('/cases');
    return (response['cases'] as List<dynamic>)
        .map((c) => AiCase.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<AiCase> requestExpertise(String consultationId,
      {String? summaryNote}) async {
    final response = await apiClient.postJson(
      '/cases/$consultationId/expertise/request',
      {
        if (summaryNote != null && summaryNote.isNotEmpty)
          'summaryNote': summaryNote
      },
    );
    return AiCase.fromJson(response['case'] as Map<String, dynamic>);
  }
}
