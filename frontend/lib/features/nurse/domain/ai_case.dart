import '../../../core/domain/korai_enums.dart';

class AiCase {
  const AiCase({
    required this.id,
    required this.status,
    required this.summary,
    required this.createdAt,
    required this.updatedAt,
    this.patientId,
    this.symptoms,
    this.urgency = UrgencyLevel.medium,
    this.earSide = EarSide.both,
    this.clinicalNotes,
    this.symptomIds = const [],
    this.symptomLabels = const [],
    this.medicalHistoryIds = const [],
    this.medicalHistoryLabels = const [],
    this.touchCheckIds = const [],
    this.touchCheckLabels = const [],
    this.touchObservations = const {},
    this.expertiseReview,
    this.effectiveSummary,
    this.aiErrorCode,
    this.aiErrorMessage,
  });

  final String id;
  final String status;
  final AiSummary summary;
  final String createdAt;
  final String updatedAt;
  final String? patientId;
  final String? symptoms;
  final UrgencyLevel urgency;
  final EarSide earSide;
  final String? clinicalNotes;
  final List<String> symptomIds;
  final List<String> symptomLabels;
  final List<String> medicalHistoryIds;
  final List<String> medicalHistoryLabels;
  final List<String> touchCheckIds;
  final List<String> touchCheckLabels;
  final Map<String, String> touchObservations;
  final ExpertiseReview? expertiseReview;
  final EffectiveSummary? effectiveSummary;
  final String? aiErrorCode;
  final String? aiErrorMessage;

  bool get isDraft => status == ConsultationStatus.draft.value;

  /// L'analyse IA a échoué côté serveur (service indisponible/timeout). La
  /// consultation est enregistrée ; l'analyse peut être relancée.
  bool get isAiFailed => status == ConsultationStatus.aiFailed.value;

  /// Message d'échec IA prêt à afficher.
  String get aiErrorDisplay =>
      aiErrorMessage ??
      "L'analyse IA n'a pas pu aboutir. Vous pouvez la relancer.";
  bool get isCompleted =>
      status == ConsultationStatus.aiCompleted.value ||
      status == ConsultationStatus.specialistCompleted.value;

  bool get hasAiResult =>
      !isDraft &&
      status != ConsultationStatus.pendingAi.value &&
      (summary.likelyDiagnosis != null ||
          summary.imageOpinion != null ||
          summary.ragOpinion != null);

  bool get hasExpertiseRequest => expertiseReview != null;

  bool get canRequestExpertise {
    if (!hasAiResult) return false;
    if (expertiseReview?.status == ExpertiseStatus.completed) return false;
    if (expertiseReview != null) return false;
    return status == ConsultationStatus.aiCompleted.value;
  }

  bool get expertiseInProgress =>
      expertiseReview != null &&
      expertiseReview!.status != ExpertiseStatus.completed &&
      status == ConsultationStatus.pendingSpecialistReview.value;

  /// Résultat affiché (effectiveSummary prioritaire sur summary IA brut).
  String get displayDiagnosis =>
      effectiveSummary?.likelyDiagnosis ??
      summary.likelyDiagnosis ??
      'Non déterminé';

  String? get displayClinicalSummary => effectiveSummary?.clinicalSummary;

  String? get displayRecommendation => effectiveSummary?.recommendation;

  AiConfidenceLabel get displayConfidence => effectiveSummary != null
      ? AiConfidenceLabel.fromApi(effectiveSummary!.confidenceLabel)
      : summary.confidenceLabel;

  bool get patientCanSeeClinicalDetails =>
      effectiveSummary?.patientVisible ?? false;

  factory AiCase.fromJson(Map<String, dynamic> json) {
    return AiCase(
      id: json['id'].toString(),
      status: json['status'].toString(),
      patientId: json['patientId']?.toString(),
      symptoms: json['symptoms']?.toString(),
      clinicalNotes: json['clinicalNotes']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
      urgency: UrgencyLevel.values.firstWhere(
        (u) =>
            u.value ==
            (json['urgency']?.toString() ?? UrgencyLevel.medium.value),
        orElse: () => UrgencyLevel.medium,
      ),
      earSide: EarSide.fromApi(json['earSide']?.toString()),
      symptomIds: _parseStringList(json['symptomIds']),
      symptomLabels: _parseStringList(json['symptomLabels']),
      medicalHistoryIds: _parseStringList(json['medicalHistoryIds']),
      medicalHistoryLabels: _parseStringList(json['medicalHistoryLabels']),
      touchCheckIds: _parseStringList(json['touchCheckIds']),
      touchCheckLabels: _parseStringList(json['touchCheckLabels']),
      touchObservations: _parseStringMap(json['touchObservations']),
      summary: AiSummary.fromJson(
        (json['organizedAiSummary'] ?? <String, dynamic>{})
            as Map<String, dynamic>,
      ),
      expertiseReview: json['expertiseReview'] != null
          ? ExpertiseReview.fromJson(
              json['expertiseReview'] as Map<String, dynamic>)
          : null,
      effectiveSummary: json['effectiveSummary'] != null
          ? EffectiveSummary.fromJson(
              json['effectiveSummary'] as Map<String, dynamic>)
          : null,
      aiErrorCode: json['aiErrorCode']?.toString(),
      aiErrorMessage: json['aiErrorMessage']?.toString(),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }

  static Map<String, String> _parseStringMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val.toString()));
    }
    return const {};
  }
}

extension AiCaseListX on List<AiCase> {
  List<AiCase> forPatient(String patientId) {
    return where((c) => c.patientId == patientId).toList();
  }

  List<AiCase> sortedByNewest() {
    final copy = [...this];
    copy.sort((a, b) {
      final aDate = DateTime.tryParse(a.createdAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b.createdAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return copy;
  }
}

class EffectiveSummary {
  const EffectiveSummary({
    required this.source,
    required this.likelyDiagnosis,
    required this.confidenceLabel,
    required this.expertValidated,
    required this.patientVisible,
    this.recommendation,
    this.clinicalSummary,
    this.patientStatusLabel,
  });

  final EffectiveSummarySource source;
  final String likelyDiagnosis;
  final String? recommendation;
  final String? clinicalSummary;
  final String confidenceLabel;
  final bool expertValidated;
  final bool patientVisible;
  final String? patientStatusLabel;

  factory EffectiveSummary.fromJson(Map<String, dynamic> json) {
    return EffectiveSummary(
      source: EffectiveSummarySource.tryFromApi(json['source']?.toString()) ??
          EffectiveSummarySource.ai,
      likelyDiagnosis: json['likelyDiagnosis']?.toString() ?? 'Non déterminé',
      recommendation: json['recommendation']?.toString(),
      clinicalSummary: json['clinicalSummary']?.toString(),
      confidenceLabel: json['confidenceLabel']?.toString() ?? 'UNKNOWN',
      expertValidated: json['expertValidated'] == true,
      patientVisible: json['patientVisible'] == true,
      patientStatusLabel: json['patientStatusLabel']?.toString(),
    );
  }
}

class ExpertiseReview {
  const ExpertiseReview({
    required this.status,
    required this.requestedAt,
    this.decision,
    this.reviewedAt,
    this.comment,
    this.correctedLikelyDiagnosis,
    this.correctedRecommendation,
    this.correctedClinicalSummary,
    this.assignedToUserId,
    this.aiSnapshot,
    this.summaryNote,
    this.noteAudio,
  });

  final ExpertiseStatus status;
  final ExpertDecision? decision;
  final String requestedAt;
  final String? reviewedAt;
  final String? comment;
  final String? correctedLikelyDiagnosis;
  final String? correctedRecommendation;
  final String? correctedClinicalSummary;
  final String? assignedToUserId;
  final AiSummarySnapshot? aiSnapshot;
  final String? summaryNote;
  final String? noteAudio;

  factory ExpertiseReview.fromJson(Map<String, dynamic> json) {
    return ExpertiseReview(
      status: ExpertiseStatus.tryFromApi(json['status']?.toString()) ??
          ExpertiseStatus.pending,
      decision: ExpertDecision.tryFromApi(json['decision']?.toString()),
      requestedAt: json['requestedAt']?.toString() ?? '',
      reviewedAt: json['reviewedAt']?.toString(),
      comment: json['comment']?.toString(),
      correctedLikelyDiagnosis: json['correctedLikelyDiagnosis']?.toString(),
      correctedRecommendation: json['correctedRecommendation']?.toString(),
      correctedClinicalSummary: json['correctedClinicalSummary']?.toString(),
      assignedToUserId: json['assignedToUserId']?.toString(),
      aiSnapshot: json['aiSnapshot'] != null
          ? AiSummarySnapshot.fromJson(
              json['aiSnapshot'] as Map<String, dynamic>)
          : null,
      summaryNote: json['summaryNote']?.toString(),
      noteAudio: json['noteAudio']?.toString(),
    );
  }
}

class AiSummarySnapshot {
  const AiSummarySnapshot({
    this.imageOpinion,
    this.ragOpinion,
    this.likelyDiagnosis,
    this.confidenceLabel,
    this.warnings = const [],
    this.sources = const [],
  });

  final String? imageOpinion;
  final String? ragOpinion;
  final String? likelyDiagnosis;
  final String? confidenceLabel;
  final List<String> warnings;
  final List<String> sources;

  factory AiSummarySnapshot.fromJson(Map<String, dynamic> json) {
    return AiSummarySnapshot(
      imageOpinion: json['imageOpinion']?.toString(),
      ragOpinion: json['ragOpinion']?.toString(),
      likelyDiagnosis: json['likelyDiagnosis']?.toString(),
      confidenceLabel: json['confidenceLabel']?.toString(),
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      sources: (json['sources'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class AiSummary {
  const AiSummary({
    required this.confidenceLabel,
    required this.warnings,
    required this.sources,
    this.imageOpinion,
    this.ragOpinion,
    this.likelyDiagnosis,
  });

  final String? imageOpinion;
  final String? ragOpinion;
  final String? likelyDiagnosis;
  final AiConfidenceLabel confidenceLabel;
  final List<String> warnings;
  final List<String> sources;

  factory AiSummary.fromJson(Map<String, dynamic> json) {
    return AiSummary(
      imageOpinion: json['imageOpinion']?.toString(),
      ragOpinion: json['ragOpinion']?.toString(),
      likelyDiagnosis: json['likelyDiagnosis']?.toString(),
      confidenceLabel:
          AiConfidenceLabel.fromApi(json['confidenceLabel']?.toString()),
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      sources: (json['sources'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
