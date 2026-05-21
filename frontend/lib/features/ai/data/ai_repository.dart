import '../../../core/api/api_client.dart';
import '../domain/ai_chat_response.dart';

/// Appels IA via le backend Korai (proxy vers FastAPI `AI_SERVICE_BASE_URL`).
///
/// Le diagnostic image passe par `POST /cases/diagnose` (anonymisation EXIF cote serveur).
class AiRepository {
  const AiRepository(this.apiClient);

  final ApiClient apiClient;

  /// JSON → backend `/ai/chat` → FastAPI `/chat`
  Future<AiChatResponse> sendChat({
    required String message,
    String? conversationId,
    bool showSources = true,
  }) async {
    final data = await apiClient.postJson('/ai/chat', {
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
      'show_sources': showSources,
    });
    return AiChatResponse.fromJson(data);
  }

  /// JSON → backend `/ai/rag/analyze` → FastAPI `/rag/analyze` (form)
  Future<AiRagAnalyzeResponse> analyzeSymptoms({
    required String symptoms,
    bool showSources = true,
  }) async {
    final data = await apiClient.postJson('/ai/rag/analyze', {
      'symptoms': symptoms,
      'show_sources': showSources,
    });
    return AiRagAnalyzeResponse.fromJson(data);
  }
}
