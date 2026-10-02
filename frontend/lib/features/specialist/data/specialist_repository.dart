import '../../../core/api/api_client.dart';
import '../../../core/domain/korai_enums.dart';
import '../../../core/utils/diagnosis_text.dart';
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
    this.aiConfidence,
    this.urgency,
    this.earSide = EarSide.both,
    this.symptomLabels = const [],
  });

  final String expertiseId;
  final String consultationId;
  final ExpertiseStatus status;
  final String createdAt;
  final String? assignedToUserId;
  final String? patientFirstName;
  final String? patientLastName;
  final String? aiDiagnosis;

  /// Libellé de confiance de l'IA (LOW / MEDIUM / HIGH / UNKNOWN).
  final String? aiConfidence;

  /// Niveau d'urgence calculé de la consultation.
  final UrgencyLevel? urgency;
  final EarSide earSide;
  final List<String> symptomLabels;

  DateTime? get createdAtDate => DateTime.tryParse(createdAt);

  /// Temps d'attente depuis la demande d'avis.
  Duration? get waiting {
    final d = createdAtDate;
    return d == null ? null : DateTime.now().difference(d.toLocal());
  }

  /// Diagnostic de l'IA prêt à afficher, ou `null` si l'analyse n'a rien
  /// produit d'exploitable (échec technique, message d'erreur brut).
  String? get aiDiagnosisDisplay {
    final d = aiDiagnosis?.trim();
    if (d == null || d.isEmpty || DiagnosisText.isTechnicalFailure(d)) return null;
    return DiagnosisText.headline(d);
  }

  String get patientLabel {
    final name = [patientFirstName, patientLastName].where((s) => s != null && s.trim().isNotEmpty).join(' ');
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
      status: ExpertiseStatus.tryFromApi(expertise['status']?.toString()) ?? ExpertiseStatus.pending,
      createdAt: expertise['createdAt']?.toString() ?? '',
      assignedToUserId: expertise['assignedToUserId']?.toString(),
      patientFirstName: patient['firstName']?.toString(),
      patientLastName: patient['lastName']?.toString(),
      aiDiagnosis: ai?['likelyDiagnosis']?.toString(),
      aiConfidence: ai?['confidenceLabel']?.toString(),
      urgency: _urgency(consultation['urgency']),
      earSide: EarSide.fromApi(consultation['earSide']?.toString()),
      symptomLabels: (consultation['symptomLabels'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
    );
  }

  static UrgencyLevel? _urgency(Object? raw) {
    final s = raw?.toString().toUpperCase();
    for (final u in UrgencyLevel.values) {
      if (u.value == s) return u;
    }
    return null;
  }
}

class SpecialistRepository {
  const SpecialistRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<ExpertiseInboxItem>> listInbox() async {
    final response = await apiClient.getJson('/expertise/inbox');
    return (response['items'] as List<dynamic>)
        .map((item) => ExpertiseInboxItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AiCase>> listCases() async {
    final response = await apiClient.getJson('/cases');
    return (response['cases'] as List<dynamic>).map((c) => AiCase.fromJson(c as Map<String, dynamic>)).toList();
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

  Future<void> submitReview(
    String consultationId, {
    required ExpertDecision decision,
    String? comment,
    String? correctedLikelyDiagnosis,
    String? correctedRecommendation,
    String? correctedClinicalSummary,
  }) async {
    await apiClient.postJson('/cases/$consultationId/expertise/review', {
      'decision': decision.value,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      if (correctedLikelyDiagnosis != null && correctedLikelyDiagnosis.isNotEmpty)
        'correctedLikelyDiagnosis': correctedLikelyDiagnosis,
      if (correctedRecommendation != null && correctedRecommendation.isNotEmpty)
        'correctedRecommendation': correctedRecommendation,
      if (correctedClinicalSummary != null && correctedClinicalSummary.isNotEmpty)
        'correctedClinicalSummary': correctedClinicalSummary,
    });
  }
}
