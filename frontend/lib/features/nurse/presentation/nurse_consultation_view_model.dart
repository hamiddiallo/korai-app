import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/domain/clinical_snapshot.dart';
import '../../../core/domain/consultation_create_payload.dart';
import '../../../core/domain/korai_enums.dart';
import '../../../core/utils/orl_image_editor.dart';
import '../data/nurse_repository.dart';
import '../domain/ai_case.dart';
import '../domain/clinical_reference_item.dart';
import '../domain/patient.dart';

class NurseConsultationViewModel extends ChangeNotifier {
  NurseConsultationViewModel({
    required NurseRepository repository,
    ImagePicker? imagePicker,
  })  : _repository = repository,
        _imagePicker = imagePicker ?? ImagePicker();

  final NurseRepository _repository;
  final ImagePicker _imagePicker;

  Patient? patient;
  File? image;
  AiCase? aiCase;
  int currentStep = 0;
  bool isLoading = false;
  bool isSubmitting = false;
  bool isEditingImage = false;
  bool requestSpecialistReview = false;
  EarSide earSide = EarSide.both;
  String? errorMessage;
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

  Future<void> loadClinicalReferences() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
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
      notifyListeners();
    }
  }

  void goToStep(int step) {
    currentStep = step.clamp(0, totalSteps - 1);
    errorMessage = null;
    notifyListeners();
  }

  void nextStep() => goToStep(currentStep + 1);

  void previousStep() => goToStep(currentStep - 1);

  AiCase? findPatientPreconsultationCase(List<AiCase> cases, String patientId) {
    final matching = cases
        .where((c) => c.patientId == patientId && (c.symptoms?.trim().isNotEmpty ?? false))
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
      notifyListeners();
      return;
    }

    applyClinicalPrefillFromNarrative(consultation.symptoms);
  }

  void setEarSide(EarSide value) {
    earSide = value;
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
  }

  void setTouchCheckObservation(String id, String value) {
    touchCheckObservations[id] = value;
    errorMessage = null;
    notifyListeners();
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
      );
    });
  }

  Future<void> pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 86,
    );
    if (picked == null) return;
    image = File(picked.path);
    errorMessage = null;
    notifyListeners();
  }

  void clearImage() {
    image = null;
    errorMessage = null;
    notifyListeners();
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
      image = await OrlImageEditor.adjustBrightness(current, brighter: brighter);
    });
  }

  Future<void> _editImage(Future<void> Function() action) async {
    if (image == null) return;
    isEditingImage = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isEditingImage = false;
      notifyListeners();
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
    aiCase = null;
    notifyListeners();
    try {
      patient ??= await _repository.createPatient(
        firstName: firstName,
        lastName: lastName,
        birthDate: age.isEmpty ? null : 'Age: $age',
        phone: phone,
        sex: sex,
        address: address,
      );

      aiCase = await _repository.diagnose(
        payload: buildConsultationPayload(
          patientId: patient!.id,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          address: address,
          age: age,
          sex: sex,
          notes: notes,
        ),
        image: selectedImage,
      );
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isSubmitting = false;
      notifyListeners();
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
    await _run(() async {
      aiCase = null;
      aiCase = await _repository.diagnose(
        payload: buildConsultationPayload(
          patientId: patientId,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          address: address,
          age: age,
          sex: sex,
          notes: notes,
        ),
        image: image,
      );
    });
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
    return ConsultationCreatePayload(
      patientId: patientId,
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
      earSide: earSide,
      requestSpecialistReview: requestSpecialistReview,
      symptomIds: ClinicalSnapshot.ids(selectedSymptomIds),
      symptomLabels: ClinicalSnapshot.labels(symptoms, selectedSymptomIds),
      medicalHistoryIds: ClinicalSnapshot.ids(selectedMedicalHistoryIds),
      medicalHistoryLabels: ClinicalSnapshot.labels(medicalHistories, selectedMedicalHistoryIds),
      touchCheckIds: ClinicalSnapshot.ids(selectedTouchCheckIds),
      touchCheckLabels: ClinicalSnapshot.labels(touchChecks, selectedTouchCheckIds),
      touchObservations: Map<String, String>.from(touchCheckObservations),
    );
  }

  void setRequestSpecialistReview(bool value) {
    requestSpecialistReview = value;
    notifyListeners();
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

  List<String> labelsFor(List<ClinicalReferenceItem> items, Set<String> selectedIds) {
    return items.where((item) => selectedIds.contains(item.id)).map((item) => item.label).toList();
  }

  Future<void> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
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
      symptomLabels.isNotEmpty || historyLabels.isNotEmpty || touchCheckLabels.isNotEmpty || (notes?.isNotEmpty ?? false);
}
