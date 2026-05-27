class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    required this.status,
    required this.messageCount,
    required this.lastMessageAt,
    this.externalConversationId,
    this.archivedAt,
  });

  final String id;
  final String title;
  final String status;
  final int messageCount;
  final DateTime lastMessageAt;
  final String? externalConversationId;
  final DateTime? archivedAt;

  bool get isArchived => status == 'ARCHIVED';
  bool get isEmpty => messageCount == 0;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? 'Nouvelle conversation',
      status: json['status']?.toString() ?? 'ACTIVE',
      messageCount: int.tryParse(json['messageCount']?.toString() ?? '') ?? 0,
      lastMessageAt:
          DateTime.tryParse(json['lastMessageAt']?.toString() ?? '') ??
              DateTime.now(),
      externalConversationId: json['externalConversationId']?.toString(),
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.tryParse(json['archivedAt'].toString()),
    );
  }

  ChatConversation copyWith({
    String? title,
    String? status,
    int? messageCount,
    DateTime? lastMessageAt,
    String? externalConversationId,
    DateTime? archivedAt,
  }) {
    return ChatConversation(
      id: id,
      title: title ?? this.title,
      status: status ?? this.status,
      messageCount: messageCount ?? this.messageCount,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      externalConversationId:
          externalConversationId ?? this.externalConversationId,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.sequence,
    required this.deliveryStatus,
    required this.createdAt,
    this.sources = const [],
    this.isRead = false,
    this.errorCode,
    this.isLocal = false,
  });

  final String id;
  final String conversationId;
  final String role;
  final String content;
  final List<String> sources;
  final int sequence;
  final String deliveryStatus;
  final bool isRead;
  final String? errorCode;
  final DateTime createdAt;
  final bool isLocal;

  bool get isUser => role == 'USER';
  bool get isAssistant => role == 'ASSISTANT';
  bool get isFailed => deliveryStatus == 'FAILED';
  bool get isPending => deliveryStatus == 'PENDING';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sourcesRaw = json['sources'];
    return ChatMessage(
      id: json['id'].toString(),
      conversationId: json['conversationId'].toString(),
      role: json['role']?.toString() ?? 'ASSISTANT',
      content: json['content']?.toString() ?? '',
      sources: sourcesRaw is List
          ? sourcesRaw.map((source) => source.toString()).toList()
          : const [],
      sequence: int.tryParse(json['sequence']?.toString() ?? '') ?? 0,
      deliveryStatus: json['deliveryStatus']?.toString() ?? 'COMPLETED',
      isRead: json['isRead'] == true,
      errorCode: json['errorCode']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  factory ChatMessage.localUser({
    required String conversationId,
    required String content,
    required int sequence,
  }) {
    return ChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      role: 'USER',
      content: content,
      sequence: sequence,
      deliveryStatus: 'PENDING',
      createdAt: DateTime.now(),
      isRead: true,
      isLocal: true,
    );
  }
}
