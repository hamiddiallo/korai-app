import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_controller.dart';
import '../data/patient_repository.dart';
import '../../nurse/domain/ai_case.dart';
import '../../nurse/domain/clinical_reference_item.dart';
import '../../nurse/domain/patient.dart';

class PatientConsultationViewModel extends ChangeNotifier {
  PatientConsultationViewModel({
    required PatientRepository repository,
    required this.session,
    ImagePicker? imagePicker,
  })  : _repository = repository,
        _imagePicker = imagePicker ?? ImagePicker();

  final PatientRepository _repository;
  final SessionController session;
  final ImagePicker _imagePicker;

  String get linkedPatientId => session.user?.linkedPatientId ?? '';

  Patient? patient;
  File? image;
  AiCase? aiCase;
  int currentStep = 0;
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;

  List<ClinicalReferenceItem> symptoms = [];
  List<ClinicalReferenceItem> medicalHistories = [];
  List<ClinicalReferenceItem> touchChecks = [];

  final selectedSymptomIds = <String>{};
  final selectedMedicalHistoryIds = <String>{};
  final selectedTouchCheckIds = <String>{};

  static const totalSteps = 4;

  Future<void> initialize() async {
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

      if (linkedPatientId.isNotEmpty) {
        try {
          patient = await _repository.getPatient(linkedPatientId);
        } catch (e) {
          debugPrint('Erreur de chargement du patient: $e');
        }
      }
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePatientProfile({
    required String firstName,
    required String lastName,
    String? phone,
    String? address,
    String? birthDate,
    String? sex,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
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
    isSubmitting = true;
    errorMessage = null;
    aiCase = null;
    notifyListeners();
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
        image: image,
      );
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isSubmitting = false;
      notifyListeners();
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

  List<String> labelsFor(List<ClinicalReferenceItem> items, Set<String> selectedIds) {
    return items.where((item) => selectedIds.contains(item.id)).map((item) => item.label).toList();
  }
}
