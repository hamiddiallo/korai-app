import '../../../core/utils/source_label.dart';

/// Reponse proxy du backend Korai → FastAPI `/chat`.
class AiChatResponse {
  const AiChatResponse({
    required this.response,
    this.conversationId,
    this.sources = const [],
  });

  final String response;
  final String? conversationId;
  final List<String> sources;

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    final sourcesRaw = json['sources'] ?? json['rag_sources'] ?? json['references'];
    return AiChatResponse(
      response: (json['response'] ?? json['answer'] ?? json['message'] ?? '').toString(),
      conversationId: (json['conversation_id'] ?? json['conversationId'])?.toString(),
      sources: SourceLabel.cleanAll(sourcesRaw),
    );
  }
}

/// Reponse proxy du backend Korai → FastAPI `/rag/analyze`.
class AiRagAnalyzeResponse {
  const AiRagAnalyzeResponse({
    this.summary,
    this.diagnosis,
    this.sources = const [],
    this.raw,
  });

  final String? summary;
  final String? diagnosis;
  final List<String> sources;
  final Map<String, dynamic>? raw;

  factory AiRagAnalyzeResponse.fromJson(Map<String, dynamic> json) {
    return AiRagAnalyzeResponse(
      summary: json['summary']?.toString(),
      diagnosis: (json['diagnosis'] ?? json['likely_diagnosis'])?.toString(),
      sources: SourceLabel.cleanAll(json['sources']),
      raw: json,
    );
  }
}
