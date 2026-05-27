import '../../../core/api/api_client.dart';
import '../domain/chat_models.dart';

class SendChatMessageResult {
  const SendChatMessageResult({
    required this.conversation,
    required this.messages,
  });

  final ChatConversation conversation;
  final List<ChatMessage> messages;
}

class RetryChatMessageResult {
  const RetryChatMessageResult({
    required this.conversation,
    required this.message,
  });

  final ChatConversation conversation;
  final ChatMessage message;
}

class ChatRepository {
  const ChatRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<ChatConversation>> listConversations({
    String status = 'ACTIVE',
  }) async {
    final data = await apiClient.getJson('/chat/conversations?status=$status');
    final raw = data['conversations'];
    if (raw is! List) return const [];
    return raw
        .map((item) => ChatConversation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatConversation> createConversation({String? title}) async {
    final data = await apiClient.postJson('/chat/conversations', {
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
    });
    return ChatConversation.fromJson(
        data['conversation'] as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> listMessages(
    String conversationId, {
    int limit = 50,
    int? beforeSequence,
  }) async {
    final query = [
      'limit=$limit',
      if (beforeSequence != null) 'beforeSequence=$beforeSequence',
    ].join('&');
    final data = await apiClient.getJson(
      '/chat/conversations/$conversationId/messages?$query',
    );
    final raw = data['messages'];
    if (raw is! List) return const [];
    return raw
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SendChatMessageResult> sendMessage({
    required String conversationId,
    required String message,
    bool showSources = true,
  }) async {
    final data = await apiClient.postJson(
      '/chat/conversations/$conversationId/messages',
      {
        'message': message,
        'showSources': showSources,
      },
    );
    return SendChatMessageResult(
      conversation: ChatConversation.fromJson(
          data['conversation'] as Map<String, dynamic>),
      messages: (data['messages'] as List<dynamic>? ?? const [])
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<RetryChatMessageResult> retryMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final data = await apiClient.postJson(
      '/chat/conversations/$conversationId/messages/$messageId/retry',
      const {},
    );
    return RetryChatMessageResult(
      conversation: ChatConversation.fromJson(
          data['conversation'] as Map<String, dynamic>),
      message: ChatMessage.fromJson(data['message'] as Map<String, dynamic>),
    );
  }

  Future<ChatConversation> updateConversation({
    required String conversationId,
    String? title,
    String? status,
  }) async {
    final data =
        await apiClient.patchJson('/chat/conversations/$conversationId', {
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (status != null) 'status': status,
    });
    return ChatConversation.fromJson(
        data['conversation'] as Map<String, dynamic>);
  }

  Future<void> markRead(String conversationId) async {
    await apiClient
        .patchJson('/chat/conversations/$conversationId/read', const {});
  }
}
