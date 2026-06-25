import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/domain/clinical_fingerprint.dart';
import '../../../core/domain/clinical_snapshot.dart';
import '../../../core/domain/clinical_urgency.dart';
import '../../../core/domain/consultation_create_payload.dart';
import '../../../core/domain/korai_enums.dart';
import '../../../core/utils/orl_image_editor.dart';
import '../data/nurse_repository.dart';
import '../domain/ai_case.dart';
import '../domain/clinical_reference_item.dart';
import '../domain/patient.dart';

class NurseConsultationState {
  const NurseConsultationState({this.version = 0});

  final int version;

  NurseConsultationState next() => NurseConsultationState(version: version + 1);
}

class NurseConsultationViewModel extends Cubit<NurseConsultationState> {
  NurseConsultationViewModel({
    required NurseRepository repository,
    ImagePicker? imagePicker,
  })  : _repository = repository,
        _imagePicker = imagePicker ?? ImagePicker(),
        super(const NurseConsultationState());

  final NurseRepository _repository;
  final ImagePicker _imagePicker;

  Patient? patient;
  File? image;
  AiCase? aiCase;
  int currentStep = 0;
  bool isLoading = false;
  bool isSubmitting = false;
  bool isEditingImage = false;
  // Défaut sur une oreille concrète : l'option « les deux » a été retirée du
  // workflow (le service IA analyse une image à la fois).
  EarSide earSide = EarSide.left;
  String? errorMessage;
  String? infoMessage;
  List<ClinicalReferenceItem> symptoms = [];
  List<ClinicalReferenceItem> medicalHistories = [];
  List<ClinicalReferenceItem> touchChecks = [];
  final selectedSymptomIds = <String>{};
  final selectedMedicalHistoryIds = <String>{};
  final selectedTouchCheckIds = <String>{};
  final touchCheckObservations = <String, String>{};

  static const totalSteps = 6;

  static const touchObservationOptions = [
    'Non réalisé',
    'Normal (négatif)',
    'Anormal — léger',
    'Anormal — modéré',
    'Anormal — sévère',
  ];

  void _emitState() {
    if (!isClosed) emit(state.next());
  }

  void setErrorMessage(String message) {
    errorMessage = message;
    infoMessage = null;
    _emitState();
  }

  Future<void> loadClinicalReferences() async {
    isLoading = true;
    errorMessage = null;
    infoMessage = null;
    _emitState();
    try {
      final results = await Future.wait([
        _repository.listClinicalItems('SYMPTOM'),
        _repository.listClinicalItems('MEDICAL_HISTORY'),
        _repository.listClinicalItems('TOUCH_CHECK'),
      ]);
      symptoms = results[0];
      medicalHistories = results[1];
      touchChecks = results[2];
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      _emitState();
    }
  }

  void goToStep(int step) {
    currentStep = step.clamp(0, totalSteps - 1);
    errorMessage = null;
    infoMessage = null;
    _emitState();
  }

  void nextStep() => goToStep(currentStep + 1);

  void previousStep() => goToStep(currentStep - 1);

  AiCase? findPatientPreconsultationCase(List<AiCase> cases, String patientId) {
    final matching = cases
        .where((c) =>
            c.patientId == patientId &&
            (c.symptoms?.trim().isNotEmpty ?? false))
        .toList();
    if (matching.isEmpty) return null;

    final drafts = matching.where((c) => c.isDraft).toList();
    if (drafts.isNotEmpty) return drafts.first;

    return matching.last;
  }

  void applyClinicalPrefillFromCase(AiCase? consultation) {
    if (consultation == null) return;
    earSide = consultation.earSide;

    if (consultation.symptomIds.isNotEmpty ||
        consultation.medicalHistoryIds.isNotEmpty ||
        consultation.touchCheckIds.isNotEmpty) {
      selectedSymptomIds
        ..clear()
        ..addAll(consultation.symptomIds);
      selectedMedicalHistoryIds
        ..clear()
        ..addAll(consultation.medicalHistoryIds);
      selectedTouchCheckIds
        ..clear()
        ..addAll(consultation.touchCheckIds);
      touchCheckObservations
        ..clear()
        ..addAll(consultation.touchObservations);
      _emitState();
      return;
    }

    applyClinicalPrefillFromNarrative(consultation.symptoms);
  }

  void setEarSide(EarSide value) {
    earSide = value;
    _emitState();
  }

  void applyClinicalPrefillFromNarrative(String? narrative) {
    if (narrative == null || narrative.trim().isEmpty) return;

    selectedSymptomIds.clear();
    selectedMedicalHistoryIds.clear();
    selectedTouchCheckIds.clear();
    touchCheckObservations.clear();

    final lower = narrative.toLowerCase();
    for (final symptom in symptoms) {
      if (lower.contains(symptom.label.toLowerCase())) {
        selectedSymptomIds.add(symptom.id);
      }
    }
    for (final history in medicalHistories) {
      if (lower.contains(history.label.toLowerCase())) {
        selectedMedicalHistoryIds.add(history.id);
      }
    }
    for (final touchCheck in touchChecks) {
      final observation =
          _parseTouchObservationFromNarrative(narrative, touchCheck.label);
      if (observation != null) {
        selectedTouchCheckIds.add(touchCheck.id);
        touchCheckObservations[touchCheck.id] = observation;
      } else if (lower.contains(touchCheck.label.toLowerCase())) {
        selectedTouchCheckIds.add(touchCheck.id);
        touchCheckObservations[touchCheck.id] = touchObservationOptions[1];
      }
    }
    _emitState();
  }

  String? _parseTouchObservationFromNarrative(String narrative, String label) {
    final lines = narrative.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      final prefixes = ['- $label:', '$label:'];
      for (final prefix in prefixes) {
        if (trimmed.startsWith(prefix)) {
          final value = trimmed.substring(prefix.length).trim();
          if (value.isNotEmpty) return value;
        }
      }
    }
    return null;
  }

  String? extractNotesFromNarrative(String? narrative) {
    if (narrative == null || narrative.isEmpty) return null;

    const markers = ['Notes libres:', 'Notes:'];
    for (final marker in markers) {
      final index = narrative.indexOf(marker);
      if (index != -1) {
        return narrative.substring(index + marker.length).trim();
      }
    }
    return null;
  }

  PreconsultationPreview buildPreconsultationPreview(String? narrative) {
    if (narrative == null || narrative.trim().isEmpty) {
      return const PreconsultationPreview();
    }

    final lower = narrative.toLowerCase();
    return PreconsultationPreview(
      symptomLabels: symptoms
          .where((item) => lower.contains(item.label.toLowerCase()))
          .map((item) => item.label)
          .toList(),
      historyLabels: medicalHistories
          .where((item) => lower.contains(item.label.toLowerCase()))
          .map((item) => item.label)
          .toList(),
      touchCheckLabels: touchChecks
          .where((item) => lower.contains(item.label.toLowerCase()))
          .map((item) => item.label)
          .toList(),
      notes: extractNotesFromNarrative(narrative),
    );
  }

  void toggleSelection(String type, String id, bool selected) {
    if (type == 'TOUCH_CHECK') {
      toggleTouchCheck(id, selected);
      return;
    }

    final target = switch (type) {
      'SYMPTOM' => selectedSymptomIds,
      'MEDICAL_HISTORY' => selectedMedicalHistoryIds,
      _ => selectedSymptomIds,
    };
    if (selected) {
      target.add(id);
    } else {
      target.remove(id);
    }
    errorMessage = null;
    infoMessage = null;
    _emitState();
  }

  void toggleTouchCheck(String id, bool selected) {
    if (selected) {
      selectedTouchCheckIds.add(id);
      touchCheckObservations.putIfAbsent(id, () => touchObservationOptions[1]);
    } else {
      selectedTouchCheckIds.remove(id);
      touchCheckObservations.remove(id);
    }
    errorMessage = null;
    infoMessage = null;
    _emitState();
  }

  void setTouchCheckObservation(String id, String value) {
    touchCheckObservations[id] = value;
    errorMessage = null;
    infoMessage = null;
    _emitState();
  }

  String? validateTouchCheckStep() {
    for (final id in selectedTouchCheckIds) {
      final observation = touchCheckObservations[id]?.trim();
      if (observation == null || observation.isEmpty) {
        return 'Sélectionnez une observation pour chaque vérification au toucher cochée.';
      }
    }
    return null;
  }

  List<String> touchCheckSummaries() {
    return touchChecks
        .where((item) => selectedTouchCheckIds.contains(item.id))
        .map((item) =>
            '${item.label}: ${touchCheckObservations[item.id] ?? "—"}')
        .toList();
  }

  Future<void> createPatient({
    required String firstName,
    required String lastName,
    String? birthDate,
    String? phone,
    String? sex,
    String? address,
  }) async {
    await _run(() async {
      patient = await _repository.createPatient(
        firstName: firstName,
        lastName: lastName,
        birthDate: birthDate,
        phone: phone,
        sex: sex,
        address: address,
      );
    });
  }

  String imageDescription = '';

  void setImageDescription(String value) {
    imageDescription = value;
    _emitState();
  }

  Future<void> pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 86,
    );
    if (picked == null) return;
    image = File(picked.path);
    errorMessage = null;
    infoMessage = null;
    _emitState();
  }

  void clearImage() {
    image = null;
    imageDescription = '';
    errorMessage = null;
    infoMessage = null;
    _emitState();
  }

  Future<void> rotateImage({required bool clockwise}) async {
    await _editImage(() async {
      final current = image;
      if (current == null) return;
      image = await OrlImageEditor.rotate(current, clockwise: clockwise);
    });
  }

  Future<void> flipImageHorizontal() async {
    await _editImage(() async {
      final current = image;
      if (current == null) return;
      image = await OrlImageEditor.flipHorizontal(current);
    });
  }

  Future<void> adjustImageBrightness({required bool brighter}) async {
    await _editImage(() async {
      final current = image;
      if (current == null) return;
      image =
          await OrlImageEditor.adjustBrightness(current, brighter: brighter);
    });
  }

  Future<void> _editImage(Future<void> Function() action) async {
    if (image == null) return;
    isEditingImage = true;
    errorMessage = null;
    _emitState();
    try {
      await action();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isEditingImage = false;
      _emitState();
    }
  }

  Future<void> submitSprint({
    required String firstName,
    required String lastName,
    required String phone,
    required String address,
    required String age,
    required String sex,
    required String notes,
  }) async {
    final selectedImage = image;

    isSubmitting = true;
    errorMessage = null;
    infoMessage = null;
    aiCase = null;
    _emitState();
    try {
      patient ??= await _repository.createPatient(
        firstName: firstName,
        lastName: lastName,
        birthDate: age.isEmpty ? null : 'Age: $age',
        phone: phone,
        sex: sex,
        address: address,
      );

      final currentPatient = patient!;
      final localPayload = buildConsultationPayload(
        patientId: currentPatient.id,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        address: address,
        age: age,
        sex: sex,
        notes: notes,
      );
      final localDraft = await _repository.savePendingDiagnosisDraft(
        patient: currentPatient,
        payload: localPayload,
        image: selectedImage,
      );

      try {
        final remotePatient = await _repository.syncLocalPatient(
          currentPatient,
          firstName: firstName,
          lastName: lastName,
          birthDate: age.isEmpty ? null : 'Age: $age',
          phone: phone,
          sex: sex,
          address: address,
        );
        patient = remotePatient;

        aiCase = await _repository.diagnose(
          payload: buildConsultationPayload(
            patientId: remotePatient.id,
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            address: address,
            age: age,
            sex: sex,
            notes: notes,
          ),
          image: selectedImage,
          localConsultationId: localDraft.localId,
        );
      } on ApiException catch (error) {
        if (error.isNetworkFailure) {
          final reused = await _tryOfflineReuse(
            localConsultationId: localDraft.localId,
            patient: currentPatient,
            payload: localPayload,
            hasImage: selectedImage != null,
          );
          if (reused != null) {
            aiCase = reused;
            infoMessage =
                'Réponse IA réutilisée hors-ligne (cas clinique identique). '
                'La consultation sera synchronisée au retour du réseau.';
          } else {
            infoMessage =
                'Consultation enregistree localement. L\'analyse IA sera synchronisee des que le reseau revient.';
          }
        } else if (error.isPermanentClientFailure) {
          errorMessage =
              'Consultation enregistree localement, mais le serveur a refuse la synchronisation : ${error.message}';
        } else {
          // 5xx / service indisponible : l\'entree reste en file et sera rejouee.
          infoMessage =
              'Consultation enregistree. ${error.message}';
        }
      } catch (_) {
        infoMessage =
            'Consultation enregistree localement. L\'analyse IA sera synchronisee des que le reseau revient.';
      }
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isSubmitting = false;
      _emitState();
    }
  }

  Future<void> diagnose({
    required String patientId,
    required String firstName,
    required String lastName,
    required String phone,
    required String address,
    required String age,
    required String sex,
    required String notes,
  }) async {
    isLoading = true;
    errorMessage = null;
    infoMessage = null;
    aiCase = null;
    _emitState();

    final selectedImage = image;
    final currentPatient = patient ??
        Patient(
          id: patientId,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          address: address,
          birthDate: age.isEmpty ? null : 'Age: $age',
          sex: sex,
        );
    final payload = buildConsultationPayload(
      patientId: currentPatient.id,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      address: address,
      age: age,
      sex: sex,
      notes: notes,
    );

    try {
      final localDraft = await _repository.savePendingDiagnosisDraft(
        patient: currentPatient,
        payload: payload,
        image: selectedImage,
      );
      try {
        aiCase = await _repository.diagnose(
          payload: payload,
          image: selectedImage,
          localConsultationId: localDraft.localId,
        );
      } on ApiException catch (error) {
        if (error.isNetworkFailure) {
          final reused = await _tryOfflineReuse(
            localConsultationId: localDraft.localId,
            patient: currentPatient,
            payload: payload,
            hasImage: selectedImage != null,
          );
          if (reused != null) {
            aiCase = reused;
            infoMessage =
                'Réponse IA réutilisée hors-ligne (cas clinique identique). '
                'La consultation sera synchronisée au retour du réseau.';
          } else {
            infoMessage =
                'Consultation enregistree localement. L\'analyse IA sera synchronisee des que le reseau revient.';
          }
        } else {
          errorMessage = error.message;
        }
      }
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      _emitState();
    }
  }

  /// Tente de réutiliser une réponse IA en cache local (consultations sans
  /// image). Retourne l'AiCase réutilisé, ou `null` si aucune correspondance.
  Future<AiCase?> _tryOfflineReuse({
    required String localConsultationId,
    required Patient patient,
    required ConsultationCreatePayload payload,
    required bool hasImage,
  }) async {
    final fingerprint = payload.clinicalFingerprint;
    if (hasImage || fingerprint == null || fingerprint.isEmpty) return null;
    try {
      return await _repository.tryReuseCachedDiagnosis(
        localConsultationId: localConsultationId,
        fingerprint: fingerprint,
        patient: patient,
        payload: payload,
      );
    } catch (_) {
      return null;
    }
  }

  ConsultationCreatePayload buildConsultationPayload({
    required String patientId,
    required String firstName,
    required String lastName,
    required String phone,
    required String address,
    required String age,
    required String sex,
    required String notes,
  }) {
    final touchSnapshot = {
      for (final id in selectedTouchCheckIds)
        id: touchCheckObservations[id] ?? '',
    };
    return ConsultationCreatePayload(
      patientId: patientId,
      imageDescription: imageDescription.trim(),
      // Empreinte clinique pour la déduplication IA (consultations sans image).
      clinicalFingerprint: ClinicalFingerprint.compute(
        earSide: earSide.value,
        sex: sex,
        age: age,
        symptomIds: ClinicalSnapshot.ids(selectedSymptomIds),
        medicalHistoryIds: ClinicalSnapshot.ids(selectedMedicalHistoryIds),
        touchObservations: touchSnapshot,
      ),
      symptoms: buildClinicalNarrative(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        address: address,
        age: age,
        sex: sex,
        notes: notes,
      ),
      clinicalNotes: notes.isEmpty ? null : notes,
      urgency: computedUrgency(),
      earSide: earSide,
      requestSpecialistReview: false,
      symptomIds: ClinicalSnapshot.ids(selectedSymptomIds),
      symptomLabels: ClinicalSnapshot.labels(symptoms, selectedSymptomIds),
      medicalHistoryIds: ClinicalSnapshot.ids(selectedMedicalHistoryIds),
      medicalHistoryLabels:
          ClinicalSnapshot.labels(medicalHistories, selectedMedicalHistoryIds),
      touchCheckIds: ClinicalSnapshot.ids(selectedTouchCheckIds),
      touchCheckLabels:
          ClinicalSnapshot.labels(touchChecks, selectedTouchCheckIds),
      touchObservations: Map<String, String>.from(touchCheckObservations),
    );
  }

  /// Relance l'analyse IA de la consultation courante en échec (AI_FAILED).
  Future<void> retryCurrentDiagnosis() async {
    final current = aiCase;
    if (current == null || !current.isAiFailed) return;

    isSubmitting = true;
    errorMessage = null;
    infoMessage = null;
    _emitState();
    try {
      final retried = await _repository.retryDiagnosis(current.id);
      aiCase = retried;
      if (retried.isAiFailed) {
        errorMessage = retried.aiErrorDisplay;
      } else {
        infoMessage = 'Analyse IA relancée avec succès.';
      }
    } on ApiException catch (error) {
      errorMessage = error.isNetworkFailure
          ? 'Pas de connexion : impossible de relancer l\'analyse pour le moment.'
          : error.message;
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isSubmitting = false;
      _emitState();
    }
  }

  Future<AiCase?> requestExpertiseForCurrentCase({String? summaryNote}) async {
    final current = aiCase;
    if (current == null || !current.canRequestExpertise) return null;

    AiCase? updated;
    await _run(() async {
      updated = await _repository.requestExpertise(current.id,
          summaryNote: summaryNote);
      aiCase = updated;
    });
    return updated;
  }

  String buildClinicalNarrative({
    required String firstName,
    required String lastName,
    required String phone,
    required String address,
    required String age,
    required String sex,
    required String notes,
  }) {
    return [
      'Patient: $firstName $lastName',
      if (age.isNotEmpty) 'Age: $age ans',
      'Sexe: $sex',
      if (phone.isNotEmpty) 'Telephone: $phone',
      if (address.isNotEmpty) 'Adresse: $address',
      'Symptomes: ${labelsFor(symptoms, selectedSymptomIds).join(', ')}',
      'Antecedents: ${labelsFor(medicalHistories, selectedMedicalHistoryIds).join(', ')}',
      ..._touchCheckNarrativeLines(),
      if (notes.isNotEmpty) 'Notes libres: $notes',
    ].join('\n');
  }

  List<String> _touchCheckNarrativeLines() {
    if (selectedTouchCheckIds.isEmpty) {
      return ['Verifications au toucher: Aucune'];
    }
    return [
      'Verifications au toucher:',
      ...touchCheckSummaries().map((line) => '- $line'),
    ];
  }

  /// Niveau d'urgence calculé automatiquement à partir des scores de danger
  /// des symptômes et antécédents cochés (aperçu ; le serveur fait autorité).
  UrgencyLevel computedUrgency() {
    final symptomScores = symptoms
        .where((s) => selectedSymptomIds.contains(s.id))
        .map((s) => s.dangerScore)
        .toList();
    final historyScores = medicalHistories
        .where((h) => selectedMedicalHistoryIds.contains(h.id))
        .map((h) => h.dangerScore)
        .toList();
    return ClinicalUrgency.compute(
      symptomScores: symptomScores,
      historyScores: historyScores,
    );
  }

  List<String> labelsFor(
      List<ClinicalReferenceItem> items, Set<String> selectedIds) {
    return items
        .where((item) => selectedIds.contains(item.id))
        .map((item) => item.label)
        .toList();
  }

  Future<void> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    infoMessage = null;
    _emitState();
    try {
      await action();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      _emitState();
    }
  }
}

class PreconsultationPreview {
  const PreconsultationPreview({
    this.symptomLabels = const [],
    this.historyLabels = const [],
    this.touchCheckLabels = const [],
    this.notes,
  });

  final List<String> symptomLabels;
  final List<String> historyLabels;
  final List<String> touchCheckLabels;
  final String? notes;

  bool get hasClinicalData =>
      symptomLabels.isNotEmpty ||
      historyLabels.isNotEmpty ||
      touchCheckLabels.isNotEmpty ||
      (notes?.isNotEmpty ?? false);
}
