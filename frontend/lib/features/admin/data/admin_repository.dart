import '../../../core/api/api_client.dart';
import '../domain/admin_models.dart';

class AdminRepository {
  const AdminRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<AdminUser>> listUsers() async {
    final response = await apiClient.getJson('/admin/users');
    return (response['users'] as List<dynamic>)
        .map((item) => AdminUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminUser> createUser(Map<String, dynamic> input) async {
    final response = await apiClient.postJson('/admin/users', input);
    return AdminUser.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<AdminUser> updateUser(String id, Map<String, dynamic> input) async {
    final response = await apiClient.patchJson('/admin/users/$id', input);
    return AdminUser.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<void> deleteUser(String id) async {
    await apiClient.deleteJson('/admin/users/$id');
  }

  Future<List<AdminPatient>> listPatients() async {
    final response = await apiClient.getJson('/admin/patients');
    return (response['patients'] as List<dynamic>)
        .map((item) => AdminPatient.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminPatient> updatePatient(
      String id, Map<String, dynamic> input) async {
    final response = await apiClient.patchJson('/admin/patients/$id', input);
    return AdminPatient.fromJson(response['patient'] as Map<String, dynamic>);
  }

  Future<AdminPatient> createPatient(Map<String, dynamic> input) async {
    final response = await apiClient.postJson('/patients', input);
    return AdminPatient.fromJson(response['patient'] as Map<String, dynamic>);
  }

  Future<void> deletePatient(String id) async {
    await apiClient.deleteJson('/admin/patients/$id');
  }

  Future<List<AdminPatient>> listDeletedPatients() async {
    final response = await apiClient.getJson('/admin/patients/deleted');
    return (response['patients'] as List<dynamic>)
        .map((item) => AdminPatient.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminPatient> restorePatient(String id) async {
    final response = await apiClient.postJson('/admin/patients/$id/restore', {});
    return AdminPatient.fromJson(response['patient'] as Map<String, dynamic>);
  }

  Future<List<AdminConsultation>> listPatientConsultations(String patientId,
      {bool includeDeleted = false}) async {
    final response = await apiClient.getJson(
        '/admin/patients/$patientId/consultations?includeDeleted=$includeDeleted');
    return (response['consultations'] as List<dynamic>)
        .map((item) => AdminConsultation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteConsultation(String id) async {
    await apiClient.deleteJson('/admin/consultations/$id');
  }

  Future<void> restoreConsultation(String id) async {
    await apiClient.postJson('/admin/consultations/$id/restore', {});
  }


  Future<List<ClinicalReferenceItem>> listClinicalItems(String type) async {
    final response =
        await apiClient.getJson('/admin/clinical-items?type=$type');
    return (response['items'] as List<dynamic>)
        .map((item) =>
            ClinicalReferenceItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ClinicalReferenceItem> createClinicalItem(
      Map<String, dynamic> input) async {
    final response = await apiClient.postJson('/admin/clinical-items', input);
    return ClinicalReferenceItem.fromJson(
        response['item'] as Map<String, dynamic>);
  }

  Future<ClinicalReferenceItem> updateClinicalItem(
      String id, Map<String, dynamic> input) async {
    final response =
        await apiClient.patchJson('/admin/clinical-items/$id', input);
    return ClinicalReferenceItem.fromJson(
        response['item'] as Map<String, dynamic>);
  }

  Future<void> deleteClinicalItem(String id) async {
    await apiClient.deleteJson('/admin/clinical-items/$id');
  }

  Future<List<Medecin>> listMedecins() async {
    final response = await apiClient.getJson('/admin/medecins');
    return (response['medecins'] as List<dynamic>? ?? const [])
        .map((e) => Medecin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createMedecin(Map<String, dynamic> input) async {
    await apiClient.postJson('/admin/medecins', input);
  }

  Future<void> updateMedecin(String id, Map<String, dynamic> input) async {
    await apiClient.patchJson('/admin/medecins/$id', input);
  }

  Future<void> deleteMedecin(String id) async {
    await apiClient.deleteJson('/admin/medecins/$id');
  }
}
