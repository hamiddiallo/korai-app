import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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
  bool requestSpecialistReview = false;
  String? errorMessage;
  List<ClinicalReferenceItem> symptoms = [];
  List<ClinicalReferenceItem> medicalHistories = [];
  List<ClinicalReferenceItem> touchChecks = [];
  final selectedSymptomIds = <String>{};
  final selectedMedicalHistoryIds = <String>{};
  final selectedTouchCheckIds = <String>{};

  static const totalSteps = 6;

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

  void toggleSelection(String type, String id, bool selected) {
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
    notifyListeners();
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
    if (selectedImage == null) {
      errorMessage = 'Ajouter une image ORL avant validation.';
      currentStep = 4;
      notifyListeners();
      return;
    }

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
        patientId: patient!.id,
        symptoms: buildClinicalNarrative(
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          address: address,
          age: age,
          sex: sex,
          notes: notes,
        ),
        image: selectedImage,
        requestSpecialistReview: requestSpecialistReview,
      );
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> diagnose({required String symptoms}) async {
    final selectedPatient = patient;
    final selectedImage = image;

    if (selectedPatient == null || selectedImage == null) {
      errorMessage = 'Creer un patient et ajouter une image avant l analyse IA.';
      notifyListeners();
      return;
    }

    await _run(() async {
      aiCase = null;
      aiCase = await _repository.diagnose(
        patientId: selectedPatient.id,
        symptoms: symptoms,
        image: selectedImage,
        requestSpecialistReview: requestSpecialistReview,
      );
    });
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
      'Verifications au toucher: ${labelsFor(touchChecks, selectedTouchCheckIds).join(', ')}',
      if (notes.isNotEmpty) 'Notes libres: $notes',
    ].join('\n');
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
