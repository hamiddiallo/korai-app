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
import '../data/local/nurse_local_dao.dart';
import '../data/nurse_repository.dart';
import '../domain/ai_case.dart';
import '../domain/clinical_reference_item.dart';
import '../domain/patient.dart';
import '../../../core/design/feedback.dart';

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

  /// Photos du tympan, une par oreille au plus. Gardées si l'oreille examinée change (rien n'est
  /// perdu sur un toucher maladroit) ; seules celles des oreilles choisies partent (`photosToSend`).
  final Map<EarSide, File> photos = {};
  AiCase? aiCase;
  int currentStep = 0;
  bool isLoading = false;
  bool isSubmitting = false;
  bool isEditingImage = false;

  /// Oreille dont la photo est en cours de retouche.
  EarSide? editingSide;

  /// Oreille(s) examinée(s). « Les deux » : une photo par tympan, chacune analysée par l'IA
  /// (le modèle classe une photo à la fois ; les symptômes ne sont analysés qu'une fois).
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

  /// Accords recueillis auprès du patient pour cette consultation (décochés
  /// tant que le soignant ne les a pas demandés).
  bool consentForAi = false;
  bool consentForTeleExpertise = false;

  static const totalSteps = 6;

  void setConsents({required bool ai, required bool teleExpertise}) {
    consentForAi = ai;
    consentForTeleExpertise = teleExpertise;
    _emitState();
  }

  /// Patient déjà enregistré : envoie au serveur les accords modifiés avant de
  /// poursuivre (réseau requis ; lève l'erreur à afficher sinon).
  Future<void> saveConsentsIfChanged() async {
    final current = patient;
    if (current == null || NurseLocalDao.isLocalId(current.id)) return;
    if (current.consentForAi == consentForAi && current.consentForTeleExpertise == consentForTeleExpertise) return;
    patient = await _repository.updateConsents(
      current.id,
      consentForAi: consentForAi,
      consentForTeleExpertise: consentForTeleExpertise,
    );
    _emitState();
  }

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
      errorMessage = friendlyError(error);
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
    final matching = cases.where((c) => c.patientId == patientId && (c.symptoms?.trim().isNotEmpty ?? false)).toList();
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
      final observation = _parseTouchObservationFromNarrative(narrative, touchCheck.label);
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
      symptomLabels:
          symptoms.where((item) => lower.contains(item.label.toLowerCase())).map((item) => item.label).toList(),
      historyLabels:
          medicalHistories.where((item) => lower.contains(item.label.toLowerCase())).map((item) => item.label).toList(),
      touchCheckLabels:
          touchChecks.where((item) => lower.contains(item.label.toLowerCase())).map((item) => item.label).toList(),
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
        .map((item) => '${item.label}: ${touchCheckObservations[item.id] ?? "—"}')
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
        consentForAi: consentForAi,
        consentForTeleExpertise: consentForTeleExpertise,
      );
    });
  }

  String imageDescription = '';

  void setImageDescription(String value) {
    imageDescription = value;
    _emitState();
  }

  /// Photos des oreilles choisies, droite puis gauche.
  Map<EarSide, File> get photosToSend => {
        for (final side in earSide.sides)
          if (photos[side] != null) side: photos[side]!,
      };

  bool get hasPhotos => photosToSend.isNotEmpty;

  Future<void> pickImage(ImageSource source, {required EarSide side}) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      // Assez pour l'IA et le spécialiste, sans saturer la file hors ligne.
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 86,
    );
    if (picked == null) return;
    photos[side] = File(picked.path);
    errorMessage = null;
    infoMessage = null;
    _emitState();
  }

  void removePhoto(EarSide side) {
    photos.remove(side);
    if (photosToSend.isEmpty) imageDescription = '';
    errorMessage = null;
    infoMessage = null;
    _emitState();
  }

  Future<void> rotateImage(EarSide side, {required bool clockwise}) =>
      _editImage(side, (photo) => OrlImageEditor.rotate(photo, clockwise: clockwise));

  Future<void> flipImageHorizontal(EarSide side) => _editImage(side, OrlImageEditor.flipHorizontal);

  Future<void> adjustImageBrightness(EarSide side, {required bool brighter}) =>
      _editImage(side, (photo) => OrlImageEditor.adjustBrightness(photo, brighter: brighter));

  Future<void> _editImage(EarSide side, Future<File> Function(File photo) transform) async {
    final current = photos[side];
    if (current == null || isEditingImage) return;
    isEditingImage = true;
    editingSide = side;
    errorMessage = null;
    _emitState();
    try {
      photos[side] = await transform(current);
    } catch (error) {
      errorMessage = friendlyError(error);
    } finally {
      isEditingImage = false;
      editingSide = null;
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
    final selectedPhotos = photosToSend;

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
        consentForAi: consentForAi,
        consentForTeleExpertise: consentForTeleExpertise,
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
        photos: selectedPhotos,
      );

      try {
        final remotePatient = await _repository.syncLocalPatient(currentPatient);
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
          photos: selectedPhotos,
          localConsultationId: localDraft.localId,
        );
      } on ApiException catch (error) {
        if (error.isNetworkFailure) {
          final reused = await _tryOfflineReuse(
            localConsultationId: localDraft.localId,
            patient: currentPatient,
            payload: localPayload,
            hasImage: selectedPhotos.isNotEmpty,
          );
          if (reused != null) {
            aiCase = reused;
            infoMessage = 'Hors ligne : réponse reprise d’une consultation équivalente (même profil clinique). '
                'La consultation sera envoyée au retour du réseau.';
          } else {
            infoMessage =
                'Consultation enregistrée sur l’appareil. L’analyse IA démarrera automatiquement au retour du réseau.';
          }
        } else if (error.isPermanentClientFailure) {
          errorMessage =
              'Consultation enregistrée sur l’appareil, mais le serveur l’a refusée : ${friendlyError(error)}';
        } else {
          // 5xx / service indisponible : l'entrée reste en file et sera rejouée.
          infoMessage = 'Consultation enregistrée. ${friendlyError(error)}';
        }
      } catch (_) {
        infoMessage =
            'Consultation enregistrée sur l’appareil. L’analyse IA démarrera automatiquement au retour du réseau.';
      }
    } catch (error) {
      errorMessage = friendlyError(error);
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

    final selectedPhotos = photosToSend;
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
        photos: selectedPhotos,
      );
      try {
        aiCase = await _repository.diagnose(
          payload: payload,
          photos: selectedPhotos,
          localConsultationId: localDraft.localId,
        );
      } on ApiException catch (error) {
        if (error.isNetworkFailure) {
          final reused = await _tryOfflineReuse(
            localConsultationId: localDraft.localId,
            patient: currentPatient,
            payload: payload,
            hasImage: selectedPhotos.isNotEmpty,
          );
          if (reused != null) {
            aiCase = reused;
            infoMessage = 'Hors ligne : réponse reprise d’une consultation équivalente (même profil clinique). '
                'La consultation sera envoyée au retour du réseau.';
          } else {
            infoMessage =
                'Consultation enregistrée sur l’appareil. L’analyse IA démarrera automatiquement au retour du réseau.';
          }
        } else {
          errorMessage = friendlyError(error);
        }
      }
    } catch (error) {
      errorMessage = friendlyError(error);
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
      for (final id in selectedTouchCheckIds) id: touchCheckObservations[id] ?? '',
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
      medicalHistoryLabels: ClinicalSnapshot.labels(medicalHistories, selectedMedicalHistoryIds),
      touchCheckIds: ClinicalSnapshot.ids(selectedTouchCheckIds),
      touchCheckLabels: ClinicalSnapshot.labels(touchChecks, selectedTouchCheckIds),
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
          ? 'Pas de connexion : l’analyse ne peut pas être relancée maintenant. Réessayez au retour du réseau.'
          : friendlyError(error);
    } catch (error) {
      errorMessage = friendlyError(error);
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
      updated = await _repository.requestExpertise(current.id, summaryNote: summaryNote);
      aiCase = updated;
    });
    return updated;
  }

  /// Récit clinique envoyé au serveur puis à l'IA : données cliniques
  /// seulement. L'identité (nom, téléphone, adresse) reste dans la fiche
  /// patient et ne figure jamais dans ce texte.
  String buildClinicalNarrative({
    required String age,
    required String sex,
    required String notes,
  }) {
    return [
      if (age.isNotEmpty) 'Age: $age ans',
      'Sexe: $sex',
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

  /// Au moins un élément pris en compte dans l'urgence a été renseigné.
  bool get hasUrgencyInput =>
      selectedSymptomIds.isNotEmpty || selectedMedicalHistoryIds.isNotEmpty || selectedTouchCheckIds.isNotEmpty;

  /// Niveau d'urgence calculé automatiquement à partir des scores de danger
  /// des symptômes, des vérifications au toucher anormales et des antécédents
  /// (aperçu ; le serveur fait autorité).
  UrgencyLevel computedUrgency() {
    final signScores = [
      for (final s in symptoms)
        if (selectedSymptomIds.contains(s.id)) s.dangerScore,
      for (final t in touchChecks)
        if (selectedTouchCheckIds.contains(t.id) &&
            ClinicalUrgency.isAbnormalTouchFinding(touchCheckObservations[t.id]))
          t.dangerScore,
    ];
    final historyScores = [
      for (final h in medicalHistories)
        if (selectedMedicalHistoryIds.contains(h.id)) h.dangerScore,
    ];
    return ClinicalUrgency.compute(signScores: signScores, historyScores: historyScores);
  }

  List<String> labelsFor(List<ClinicalReferenceItem> items, Set<String> selectedIds) {
    return items.where((item) => selectedIds.contains(item.id)).map((item) => item.label).toList();
  }

  Future<void> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    infoMessage = null;
    _emitState();
    try {
      await action();
    } catch (error) {
      errorMessage = friendlyError(error);
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
