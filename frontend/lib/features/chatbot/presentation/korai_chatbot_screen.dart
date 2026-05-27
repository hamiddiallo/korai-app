import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_client.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';
import 'korai_chatbot_cubit.dart';

class KoraiChatbotScreen extends StatefulWidget {
  const KoraiChatbotScreen({
    super.key,
    required this.apiClient,
    this.userName,
  });

  final ApiClient apiClient;
  final String? userName;

  @override
  State<KoraiChatbotScreen> createState() => _KoraiChatbotScreenState();
}

class _KoraiChatbotScreenState extends State<KoraiChatbotScreen> {
  late final KoraiChatbotCubit _chatbotCubit;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _suggestions = [
    'Qu\'est-ce que KORAI ?',
    'Comment utiliser l\'otoscope ?',
    'Quels sont les signes d\'une otite moyenne ?',
    'Comment soulager une otalgie en urgence ?',
    'Quelle est la précision du diagnostic IA ?',
  ];

  @override
  void initState() {
    super.initState();
    _chatbotCubit = KoraiChatbotCubit(
      repository: ChatRepository(widget.apiClient),
    );
    _chatbotCubit.loadInitial();
  }

  @override
  void dispose() {
    _chatbotCubit.close();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty || _chatbotCubit.state.isSending) return;
    _inputController.clear();
    await _chatbotCubit.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KoraiChatbotCubit, KoraiChatbotState>(
      bloc: _chatbotCubit,
      listener: (context, state) => _scrollToBottom(),
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          drawer: _buildConversationDrawer(state),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            leading: Builder(
              builder: (context) => IconButton(
                tooltip: 'Historique',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology_rounded,
                      color: Colors.redAccent, size: 22),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KORAI Chatbot',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B)),
                    ),
                    Row(
                      children: [
                        Icon(Icons.circle, color: Colors.green, size: 8),
                        SizedBox(width: 4),
                        Text(
                          'IA connectée',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Nouvelle conversation',
                onPressed: state.isSending
                    ? null
                    : () => _chatbotCubit.createNewConversation(),
                icon: const Icon(Icons.add_comment_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              if (state.errorBanner != null)
                Material(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade800, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorBanner!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: state.isLoadingConversations && state.messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.showWelcome
                        ? _buildWelcomePanel()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: state.messages.length +
                                (state.hasMoreMessages ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (state.hasMoreMessages && index == 0) {
                                return Center(
                                  child: TextButton.icon(
                                    onPressed: state.isLoadingMessages
                                        ? null
                                        : _chatbotCubit.loadOlderMessages,
                                    icon: state.isLoadingMessages
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.history_rounded),
                                    label: const Text('Charger plus ancien'),
                                  ),
                                );
                              }
                              final message = state.messages[
                                  index - (state.hasMoreMessages ? 1 : 0)];
                              return _buildMessageBubble(message, state);
                            },
                          ),
              ),
              if (state.isSending) _buildTypingIndicator(),
              _buildInputBar(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConversationDrawer(KoraiChatbotState state) {
    final conversations = state.visibleConversations;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Conversations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Nouvelle conversation',
                    onPressed: _chatbotCubit.createNewConversation,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (state.isLoadingConversations)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Aucune conversation enregistrée pour le moment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final selected =
                            state.activeConversation?.id == conversation.id;
                        return ListTile(
                          selected: selected,
                          selectedTileColor: Colors.indigo.shade50,
                          leading: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: selected
                                ? Colors.indigo.shade700
                                : Colors.grey.shade600,
                          ),
                          title: Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            _relativeDate(conversation.lastMessageAt),
                            maxLines: 1,
                          ),
                          trailing: IconButton(
                            tooltip: 'Archiver',
                            onPressed: () =>
                                _chatbotCubit.archiveConversation(conversation),
                            icon: const Icon(Icons.archive_outlined, size: 20),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            _chatbotCubit.openConversation(conversation);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePanel() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 24),
        CircleAvatar(
          radius: 32,
          backgroundColor: Colors.red.shade50,
          child: const Icon(Icons.psychology_rounded,
              color: Colors.redAccent, size: 32),
        ),
        const SizedBox(height: 18),
        Text(
          'Bonjour ${widget.userName ?? 'Praticien'}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Posez une question ORL générale. Les conversations sont maintenant conservées dans votre historique.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, height: 1.35),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _suggestions
              .map(
                (suggestion) => ActionChip(
                  label: Text(suggestion),
                  onPressed: () => _handleSendMessage(suggestion),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message, KoraiChatbotState state) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser
              ? Colors.indigo.shade600
              : message.isFailed
                  ? Colors.red.shade50
                  : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: message.isUser
              ? null
              : Border.all(
                  color: message.isFailed
                      ? Colors.red.shade200
                      : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: message.isUser
                    ? Colors.white
                    : message.isFailed
                        ? Colors.red.shade900
                        : const Color(0xFF334155),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.sources
                    .take(4)
                    .map(
                      (source) => Chip(
                        label: Text(
                          source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (message.isFailed && message.isAssistant) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: state.retryingMessageId == null
                    ? () => _chatbotCubit.retryMessage(message)
                    : null,
                icon: state.retryingMessageId == message.id
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}",
                style: TextStyle(
                  color: message.isUser ? Colors.white60 : Colors.grey.shade400,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'KORAI réfléchit',
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(KoraiChatbotState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                onSubmitted: _handleSendMessage,
                enabled: !state.isSending,
                decoration: InputDecoration(
                  hintText: 'Posez une question à KORAI...',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.indigo.shade300),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  fillColor: Colors.grey.shade50,
                  filled: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Colors.indigo,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
                onPressed: state.isSending
                    ? null
                    : () => _handleSendMessage(_inputController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return 'à l’instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}
