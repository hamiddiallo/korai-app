import '../api/api_client.dart';

/// Établissement de santé (poste, centre, hôpital) : les soignants d'un même
/// établissement partagent les dossiers de ses patients.
class Facility {
  const Facility({required this.id, required this.name});

  final String id;
  final String name;

  factory Facility.fromJson(Map<String, dynamic> json) =>
      Facility(id: json['id'].toString(), name: json['name'].toString());
}

class FacilityRepository {
  FacilityRepository(this.apiClient);

  final ApiClient apiClient;

  /// Liste publique (inscription, avant toute connexion).
  Future<List<Facility>> list() async {
    final response = await apiClient.getJson('/facilities');
    return (response['facilities'] as List<dynamic>)
        .map((item) => Facility.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
