import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/chat_repository.dart';
import '../domain/chat_models.dart';

class KoraiChatbotState {
  const KoraiChatbotState({
    this.conversations = const [],
    this.activeConversation,
    this.messages = const [],
    this.isLoadingConversations = false,
    this.isLoadingMessages = false,
    this.isSending = false,
    this.retryingMessageId,
    this.errorBanner,
    this.hasMoreMessages = true,
  });

  final List<ChatConversation> conversations;
  final ChatConversation? activeConversation;
  final List<ChatMessage> messages;
  final bool isLoadingConversations;
  final bool isLoadingMessages;
  final bool isSending;
  final String? retryingMessageId;
  final String? errorBanner;
  final bool hasMoreMessages;

  List<ChatConversation> get visibleConversations =>
      conversations.where((conversation) => !conversation.isEmpty).toList();

  bool get showWelcome => messages.isEmpty && !isLoadingMessages;

  KoraiChatbotState copyWith({
    List<ChatConversation>? conversations,
    Object? activeConversation = _unset,
    List<ChatMessage>? messages,
    bool? isLoadingConversations,
    bool? isLoadingMessages,
    bool? isSending,
    Object? retryingMessageId = _unset,
    Object? errorBanner = _unset,
    bool? hasMoreMessages,
  }) {
    return KoraiChatbotState(
      conversations: conversations ?? this.conversations,
      activeConversation: identical(activeConversation, _unset)
          ? this.activeConversation
          : activeConversation as ChatConversation?,
      messages: messages ?? this.messages,
      isLoadingConversations:
          isLoadingConversations ?? this.isLoadingConversations,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isSending: isSending ?? this.isSending,
      retryingMessageId: identical(retryingMessageId, _unset)
          ? this.retryingMessageId
          : retryingMessageId as String?,
      errorBanner: identical(errorBanner, _unset)
          ? this.errorBanner
          : errorBanner as String?,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
    );
  }
}

const Object _unset = Object();

class KoraiChatbotCubit extends Cubit<KoraiChatbotState> {
  KoraiChatbotCubit({
    required ChatRepository repository,
  })  : _repository = repository,
        super(const KoraiChatbotState());

  final ChatRepository _repository;

  Future<void> loadInitial() async {
    emit(state.copyWith(isLoadingConversations: true, errorBanner: null));
    try {
      final conversations = await _repository.listConversations();
      if (conversations.isEmpty) {
        emit(
          state.copyWith(
            conversations: conversations,
            activeConversation: null,
            messages: const [],
            isLoadingConversations: false,
            hasMoreMessages: false,
          ),
        );
        return;
      }

      final active = conversations.first;
      final messages = await _repository.listMessages(active.id);
      await _repository.markRead(active.id);
      if (isClosed) return;
      emit(
        state.copyWith(
          conversations: conversations,
          activeConversation: active,
          messages: messages,
          isLoadingConversations: false,
          hasMoreMessages: messages.length >= 50,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingConversations: false,
          errorBanner: error.toString(),
        ),
      );
    }
  }

  Future<void> createNewConversation() async {
    emit(state.copyWith(errorBanner: null));
    try {
      final conversation = await _repository.createConversation();
      if (isClosed) return;
      emit(
        state.copyWith(
          conversations: _upsertConversation(state.conversations, conversation),
          activeConversation: conversation,
          messages: const [],
          hasMoreMessages: false,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(errorBanner: error.toString()));
    }
  }

  Future<void> openConversation(ChatConversation conversation) async {
    if (state.activeConversation?.id == conversation.id &&
        state.messages.isNotEmpty) {
      return;
    }

    emit(
      state.copyWith(
        activeConversation: conversation,
        isLoadingMessages: true,
        errorBanner: null,
      ),
    );
    try {
      final messages = await _repository.listMessages(conversation.id);
      await _repository.markRead(conversation.id);
      if (isClosed) return;
      emit(
        state.copyWith(
          messages: messages,
          isLoadingMessages: false,
          hasMoreMessages: messages.length >= 50,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingMessages: false,
          errorBanner: error.toString(),
        ),
      );
    }
  }

  Future<void> loadOlderMessages() async {
    final conversation = state.activeConversation;
    if (conversation == null ||
        state.messages.isEmpty ||
        state.isLoadingMessages ||
        !state.hasMoreMessages) {
      return;
    }

    final firstSequence = state.messages.first.sequence;
    emit(state.copyWith(isLoadingMessages: true, errorBanner: null));
    try {
      final older = await _repository.listMessages(
        conversation.id,
        beforeSequence: firstSequence,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          messages: [...older, ...state.messages],
          isLoadingMessages: false,
          hasMoreMessages: older.length >= 50,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingMessages: false,
          errorBanner: error.toString(),
        ),
      );
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    try {
      final conversation = await _ensureActiveConversation();
      final sequence =
          state.messages.isEmpty ? 1 : state.messages.last.sequence + 1;
      final localMessage = ChatMessage.localUser(
        conversationId: conversation.id,
        content: trimmed,
        sequence: sequence,
      );

      emit(
        state.copyWith(
          messages: [...state.messages, localMessage],
          isSending: true,
          errorBanner: null,
        ),
      );

      final result = await _repository.sendMessage(
        conversationId: conversation.id,
        message: trimmed,
      );
      if (isClosed) return;

      final withoutLocal = state.messages
          .where((message) => message.id != localMessage.id)
          .toList();
      emit(
        state.copyWith(
          conversations:
              _upsertConversation(state.conversations, result.conversation),
          activeConversation: result.conversation,
          messages: _mergeMessages(withoutLocal, result.messages),
          isSending: false,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSending: false,
          errorBanner: error.toString(),
        ),
      );
    }
  }

  Future<void> retryMessage(ChatMessage message) async {
    final conversation = state.activeConversation;
    if (conversation == null ||
        !message.isFailed ||
        state.retryingMessageId != null) {
      return;
    }

    emit(state.copyWith(retryingMessageId: message.id, errorBanner: null));
    try {
      final result = await _repository.retryMessage(
        conversationId: conversation.id,
        messageId: message.id,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          conversations:
              _upsertConversation(state.conversations, result.conversation),
          activeConversation: result.conversation,
          messages: _replaceMessage(state.messages, result.message),
          retryingMessageId: null,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          retryingMessageId: null,
          errorBanner: error.toString(),
        ),
      );
    }
  }

  Future<void> archiveConversation(ChatConversation conversation) async {
    try {
      final updated = await _repository.updateConversation(
        conversationId: conversation.id,
        status: 'ARCHIVED',
      );
      if (isClosed) return;
      final remaining =
          state.conversations.where((item) => item.id != updated.id).toList();
      emit(
        state.copyWith(
          conversations: remaining,
          activeConversation: state.activeConversation?.id == updated.id
              ? null
              : state.activeConversation,
          messages: state.activeConversation?.id == updated.id
              ? const []
              : state.messages,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(errorBanner: error.toString()));
    }
  }

  Future<ChatConversation> _ensureActiveConversation() async {
    final existing = state.activeConversation;
    if (existing != null && existing.status == 'ACTIVE') return existing;

    final conversation = await _repository.createConversation();
    if (!isClosed) {
      emit(
        state.copyWith(
          conversations: _upsertConversation(state.conversations, conversation),
          activeConversation: conversation,
        ),
      );
    }
    return conversation;
  }

  List<ChatConversation> _upsertConversation(
    List<ChatConversation> conversations,
    ChatConversation conversation,
  ) {
    final withoutCurrent =
        conversations.where((item) => item.id != conversation.id).toList();
    return [conversation, ...withoutCurrent]
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> current,
    List<ChatMessage> incoming,
  ) {
    final byId = <String, ChatMessage>{
      for (final message in current)
        if (!message.isLocal) message.id: message,
      for (final message in incoming) message.id: message,
    };
    return byId.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }

  List<ChatMessage> _replaceMessage(
    List<ChatMessage> current,
    ChatMessage replacement,
  ) {
    return current
        .map((message) => message.id == replacement.id ? replacement : message)
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }
}
