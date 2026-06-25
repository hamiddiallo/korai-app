import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/domain/clinical_snapshot.dart';
import '../../../core/domain/consultation_create_payload.dart';
import '../../../core/domain/korai_enums.dart';
import '../../../core/utils/orl_image_editor.dart';
import '../data/patient_repository.dart';
import '../../nurse/domain/ai_case.dart';
import '../../nurse/domain/clinical_reference_item.dart';
import '../../nurse/domain/patient.dart';

class PatientConsultationState {
  const PatientConsultationState({this.version = 0});

  final int version;

  PatientConsultationState next() =>
      PatientConsultationState(version: version + 1);
}

class PatientConsultationViewModel extends Cubit<PatientConsultationState> {
  PatientConsultationViewModel({
    required PatientRepository repository,
    required this.session,
    ImagePicker? imagePicker,
  })  : _repository = repository,
        _imagePicker = imagePicker ?? ImagePicker(),
        super(const PatientConsultationState());

  final PatientRepository _repository;
  final AuthCubit session;
  final ImagePicker _imagePicker;

  String get linkedPatientId => session.user?.linkedPatientId ?? '';

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

  List<ClinicalReferenceItem> symptoms = [];
  List<ClinicalReferenceItem> medicalHistories = [];
  List<ClinicalReferenceItem> touchChecks = [];

  final selectedSymptomIds = <String>{};
  final selectedMedicalHistoryIds = <String>{};
  final selectedTouchCheckIds = <String>{};
  String? readOnlyNotes;
  List<AiCase> consultations = [];

  static const totalSteps = 4;

  bool get isReadOnly => patient?.isValidated == true;

  void _emitState() {
    if (!isClosed) emit(state.next());
  }

  Future<void> initialize() async {
    isLoading = true;
    errorMessage = null;
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

      if (linkedPatientId.isNotEmpty) {
        try {
          patient = await _repository.getPatient(linkedPatientId);
          if (isReadOnly) {
            await _loadValidatedDossierData();
          }
        } catch (e) {
          debugPrint('Erreur de chargement du patient: $e');
        }
      }
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      _emitState();
    }
  }

  Future<void> _loadValidatedDossierData() async {
    try {
      consultations = (await _repository.listCases()).sortedByNewest();
      final preCase = _findPreconsultationCase(consultations, linkedPatientId);
      applyClinicalPrefillFromCase(preCase);
      readOnlyNotes = _extractNotesFromNarrative(preCase?.symptoms);
    } catch (e) {
      debugPrint('Erreur chargement dossier validé: $e');
    }
  }

  AiCase? _findPreconsultationCase(List<AiCase> cases, String patientId) {
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
      if (lower.contains(touchCheck.label.toLowerCase())) {
        selectedTouchCheckIds.add(touchCheck.id);
      }
    }
    _emitState();
  }

  String? _extractNotesFromNarrative(String? narrative) {
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

  Future<void> updatePatientProfile({
    required String firstName,
    required String lastName,
    String? phone,
    String? address,
    String? birthDate,
    String? sex,
  }) async {
    if (isReadOnly) {
      errorMessage =
          'Dossier validé : modification réservée au professionnel de santé.';
      _emitState();
      return;
    }

    isLoading = true;
    errorMessage = null;
    _emitState();
    try {
      final updated = await _repository.updatePatient(linkedPatientId, {
        'firstName': firstName,
        'lastName': lastName,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
        if (birthDate != null) 'birthDate': birthDate,
        if (sex != null) 'sex': sex,
      });
      patient = updated;
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
    _emitState();
  }

  void nextStep() => goToStep(currentStep + 1);

  void previousStep() => goToStep(currentStep - 1);

  void toggleSelection(String type, String id, bool selected) {
    if (isReadOnly) return;

    final target = switch (type) {
      'SYMPTOM' => selectedSymptomIds,
      'MEDICAL_HISTORY' => selectedMedicalHistoryIds,
      'TOUCH_CHECK' => selectedTouchCheckIds,
      _ => selectedSymptomIds,
    };
    if (selected) {
      target.add(id);
    } else {
      target.remove(id);
    }
    errorMessage = null;
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
    _emitState();
  }

  void clearImage() {
    image = null;
    errorMessage = null;
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
    if (isReadOnly) {
      errorMessage =
          'Dossier validé : la pré-consultation ne peut plus être modifiée.';
      _emitState();
      return;
    }

    isSubmitting = true;
    errorMessage = null;
    aiCase = null;
    _emitState();
    try {
      final updatedPatient = await _repository.updatePatient(linkedPatientId, {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'address': address,
        'birthDate': age.isEmpty ? null : 'Age: $age ans',
        'sex': sex,
        'isValidated': false,
      });
      patient = updatedPatient;

      aiCase = await _repository.diagnose(
        payload: buildConsultationPayload(
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
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isSubmitting = false;
      _emitState();
    }
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
      'Patient: $firstName $lastName (Autodéclaration)',
      if (age.isNotEmpty) 'Age: $age ans',
      'Sexe: $sex',
      if (phone.isNotEmpty) 'Telephone: $phone',
      if (address.isNotEmpty) 'Adresse: $address',
      'Symptomes: ${labelsFor(symptoms, selectedSymptomIds).join(', ')}',
      'Antecedents: ${labelsFor(medicalHistories, selectedMedicalHistoryIds).join(', ')}',
      'Verifications au toucher: ${labelsFor(touchChecks, selectedTouchCheckIds).join(', ')}',
      if (notes.isNotEmpty) 'Notes libres: $notes',
    ].join('\n');
  }

  List<String> labelsFor(
      List<ClinicalReferenceItem> items, Set<String> selectedIds) {
    return items
        .where((item) => selectedIds.contains(item.id))
        .map((item) => item.label)
        .toList();
  }

  ConsultationCreatePayload buildConsultationPayload({
    required String firstName,
    required String lastName,
    required String phone,
    required String address,
    required String age,
    required String sex,
    required String notes,
  }) {
    return ConsultationCreatePayload(
      patientId: linkedPatientId,
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
      showSources: image != null,
      symptomIds: ClinicalSnapshot.ids(selectedSymptomIds),
      symptomLabels: ClinicalSnapshot.labels(symptoms, selectedSymptomIds),
      medicalHistoryIds: ClinicalSnapshot.ids(selectedMedicalHistoryIds),
      medicalHistoryLabels:
          ClinicalSnapshot.labels(medicalHistories, selectedMedicalHistoryIds),
      touchCheckIds: ClinicalSnapshot.ids(selectedTouchCheckIds),
      touchCheckLabels:
          ClinicalSnapshot.labels(touchChecks, selectedTouchCheckIds),
    );
  }
}
