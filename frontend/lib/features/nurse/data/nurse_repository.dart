import 'dart:io';

import '../../../core/api/api_client.dart';
import '../../../core/domain/consultation_create_payload.dart';
import '../domain/ai_case.dart';
import '../domain/clinical_reference_item.dart';
import '../domain/patient.dart';

class NurseRepository {
  const NurseRepository(this.apiClient);

  final ApiClient apiClient;

  Future<Patient> createPatient({
    required String firstName,
    required String lastName,
    String? birthDate,
    String? phone,
    String? sex,
    String? address,
  }) async {
    final response = await apiClient.postJson('/patients', {
      'firstName': firstName,
      'lastName': lastName,
      if (birthDate != null && birthDate.isNotEmpty) 'birthDate': birthDate,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (sex != null && sex.isNotEmpty) 'sex': sex,
      if (address != null && address.isNotEmpty) 'address': address,
      'consentForAi': true,
      'consentForTeleExpertise': true,
    });
    return Patient.fromJson(response['patient'] as Map<String, dynamic>);
  }

  Future<List<Patient>> listPatients() async {
    final response = await apiClient.getJson('/patients');
    return (response['patients'] as List<dynamic>)
        .map((p) => Patient.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<Patient> validatePatient(String id) async {
    final response = await apiClient.patchJson('/patients/$id', {
      'isValidated': true,
    });
    return Patient.fromJson(response['patient'] as Map<String, dynamic>);
  }

  Future<List<ClinicalReferenceItem>> listClinicalItems(String type) async {
    final response = await apiClient.getJson('/clinical-items?type=$type');
    return (response['items'] as List<dynamic>)
        .map((item) => ClinicalReferenceItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AiCase> diagnose({
    required ConsultationCreatePayload payload,
    required File image,
  }) async {
    final response = await apiClient.postMultipart(
      path: '/cases/diagnose',
      fileField: 'file',
      file: image,
      fields: payload.toMultipartFields(),
    );
    return AiCase.fromJson(response['case'] as Map<String, dynamic>);
  }

  Future<List<AiCase>> listCases() async {
    final response = await apiClient.getJson('/cases');
    return (response['cases'] as List<dynamic>)
        .map((c) => AiCase.fromJson(c as Map<String, dynamic>))
        .toList();
  }
}
