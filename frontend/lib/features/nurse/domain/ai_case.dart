class AiCase {
  const AiCase({
    required this.id,
    required this.status,
    required this.summary,
    this.patientId,
    this.symptoms,
  });

  final String id;
  final String status;
  final AiSummary summary;
  final String? patientId;
  final String? symptoms;

  factory AiCase.fromJson(Map<String, dynamic> json) {
    return AiCase(
      id: json['id'].toString(),
      status: json['status'].toString(),
      patientId: json['patientId']?.toString(),
      symptoms: json['symptoms']?.toString(),
      summary: AiSummary.fromJson(
        (json['organizedAiSummary'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      ),
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
  final String confidenceLabel;
  final List<String> warnings;
  final List<String> sources;

  factory AiSummary.fromJson(Map<String, dynamic> json) {
    return AiSummary(
      imageOpinion: json['imageOpinion']?.toString(),
      ragOpinion: json['ragOpinion']?.toString(),
      likelyDiagnosis: json['likelyDiagnosis']?.toString(),
      confidenceLabel: json['confidenceLabel']?.toString() ?? 'UNKNOWN',
      warnings: (json['warnings'] as List<dynamic>? ?? const []).map((item) => item.toString()).toList(),
      sources: (json['sources'] as List<dynamic>? ?? const []).map((item) => item.toString()).toList(),
    );
  }
}
