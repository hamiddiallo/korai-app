import '../../../core/api/api_client.dart';
import '../../../core/domain/korai_enums.dart';
import '../../nurse/domain/ai_case.dart';

class ExpertiseInboxItem {
  const ExpertiseInboxItem({
    required this.expertiseId,
    required this.consultationId,
    required this.status,
    required this.createdAt,
    this.assignedToUserId,
    this.patientFirstName,
    this.patientLastName,
    this.aiDiagnosis,
  });

  final String expertiseId;
  final String consultationId;
  final ExpertiseStatus status;
  final String createdAt;
  final String? assignedToUserId;
  final String? patientFirstName;
  final String? patientLastName;
  final String? aiDiagnosis;

  String get patientLabel {
    final name = [patientFirstName, patientLastName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(' ');
    return name.isEmpty ? 'Patient' : name;
  }

  factory ExpertiseInboxItem.fromJson(Map<String, dynamic> json) {
    final expertise = json['expertise'] as Map<String, dynamic>? ?? {};
    final patient = json['patient'] as Map<String, dynamic>? ?? {};
    final consultation = json['consultation'] as Map<String, dynamic>? ?? {};
    final ai = consultation['aiResponse'] as Map<String, dynamic>?;
    return ExpertiseInboxItem(
      expertiseId: expertise['id']?.toString() ?? '',
      consultationId: expertise['consultationId']?.toString() ?? '',
      status: ExpertiseStatus.tryFromApi(expertise['status']?.toString()) ??
          ExpertiseStatus.pending,
      createdAt: expertise['createdAt']?.toString() ?? '',
      assignedToUserId: expertise['assignedToUserId']?.toString(),
      patientFirstName: patient['firstName']?.toString(),
      patientLastName: patient['lastName']?.toString(),
      aiDiagnosis: ai?['likelyDiagnosis']?.toString(),
    );
  }
}

class SpecialistRepository {
  const SpecialistRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<ExpertiseInboxItem>> listInbox() async {
    final response = await apiClient.getJson('/expertise/inbox');
    return (response['items'] as List<dynamic>)
        .map(
            (item) => ExpertiseInboxItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AiCase>> listCases() async {
    final response = await apiClient.getJson('/cases');
    return (response['cases'] as List<dynamic>)
        .map((c) => AiCase.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<AiCase?> findCase(String consultationId) async {
    final cases = await listCases();
    for (final c in cases) {
      if (c.id == consultationId) return c;
    }
    return null;
  }

  Future<void> assign(String consultationId) async {
    await apiClient.postJson('/cases/$consultationId/expertise/assign', {});
  }

  Future<AiCase> submitReview(
    String consultationId, {
    required ExpertDecision decision,
    String? comment,
    String? correctedLikelyDiagnosis,
    String? correctedRecommendation,
    String? correctedClinicalSummary,
  }) async {
    final response =
        await apiClient.postJson('/cases/$consultationId/expertise/review', {
      'decision': decision.value,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      if (correctedLikelyDiagnosis != null &&
          correctedLikelyDiagnosis.isNotEmpty)
        'correctedLikelyDiagnosis': correctedLikelyDiagnosis,
      if (correctedRecommendation != null && correctedRecommendation.isNotEmpty)
        'correctedRecommendation': correctedRecommendation,
      if (correctedClinicalSummary != null &&
          correctedClinicalSummary.isNotEmpty)
        'correctedClinicalSummary': correctedClinicalSummary,
    });
    // Recharger le cas complet pour l'affichage
    final expertise = response['expertise'] as Map<String, dynamic>?;
    final caseId = expertise?['consultationId']?.toString() ?? consultationId;
    return (await findCase(caseId))!;
  }
}
