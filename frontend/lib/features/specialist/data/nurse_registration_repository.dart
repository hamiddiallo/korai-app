import '../../../core/api/api_client.dart';

class NurseRequest {
  const NurseRequest({
    required this.id,
    required this.fullName,
    required this.email,
    required this.accountStatus,
    this.healthFacility,
    this.phone,
    this.supervisorMatricule,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String accountStatus; // ACTIVE | PENDING | REJECTED
  final String? healthFacility;
  final String? phone;
  final String? supervisorMatricule;
  final String? createdAt;

  bool get isPending => accountStatus == 'PENDING';

  factory NurseRequest.fromJson(Map<String, dynamic> json) {
    return NurseRequest(
      id: json['id'].toString(),
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      accountStatus: json['accountStatus']?.toString() ?? 'PENDING',
      healthFacility: json['healthFacility']?.toString(),
      phone: json['phone']?.toString(),
      supervisorMatricule: json['supervisorMatricule']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class NurseRegistrationRepository {
  NurseRegistrationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<NurseRequest>> list() async {
    final response = await _apiClient.getJson('/registrations/nurses');
    return (response['requests'] as List<dynamic>? ?? const [])
        .map((e) => NurseRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> approve(String nurseId) async {
    await _apiClient.postJson('/registrations/nurses/$nurseId/approve', const {});
  }

  Future<void> reject(String nurseId, {String? reason}) async {
    await _apiClient.postJson('/registrations/nurses/$nurseId/reject', {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }
}
