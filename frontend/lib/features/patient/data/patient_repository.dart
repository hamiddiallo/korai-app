import 'dart:io';

import '../../../core/api/api_client.dart';
import '../../../core/domain/consultation_create_payload.dart';
import '../../nurse/domain/ai_case.dart';
import '../../nurse/domain/clinical_reference_item.dart';
import '../../nurse/domain/patient.dart';

class PatientRepository {
  const PatientRepository(this.apiClient);

  final ApiClient apiClient;

  Future<Patient> getPatient(String id) async {
    final response = await apiClient.getJson('/patients/$id');
    return Patient.fromJson(response['patient'] as Map<String, dynamic>);
  }

  Future<Patient> updatePatient(String id, Map<String, dynamic> data) async {
    final response = await apiClient.patchJson('/patients/$id', data);
    return Patient.fromJson(response['patient'] as Map<String, dynamic>);
  }

  Future<List<AiCase>> listCases() async {
    final response = await apiClient.getJson('/cases');
    return (response['cases'] as List<dynamic>)
        .map((item) => AiCase.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ClinicalReferenceItem>> listClinicalItems(String type) async {
    final response = await apiClient.getJson('/clinical-items?type=$type');
    return (response['items'] as List<dynamic>)
        .map((item) => ClinicalReferenceItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AiCase> diagnose({
    required ConsultationCreatePayload payload,
    File? image,
  }) async {
    if (image != null) {
      final response = await apiClient.postMultipart(
        path: '/cases/diagnose',
        fileField: 'file',
        file: image,
        fields: payload.toMultipartFields(),
      );
      return AiCase.fromJson(response['case'] as Map<String, dynamic>);
    }

    final response = await apiClient.postJson('/cases/diagnose', payload.toJsonBody());
    return AiCase.fromJson(response['case'] as Map<String, dynamic>);
  }
}
