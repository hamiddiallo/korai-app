import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_client.dart';
import '../../../core/design/design.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';
import 'korai_chatbot_cubit.dart';

/// Assistant Korai : questions ORL générales, conversations conservées.
/// Les réponses de l'IA portent le filet aqua, comme partout dans l'app.
class KoraiChatbotScreen extends StatefulWidget {
  const KoraiChatbotScreen({
    super.key,
    required this.apiClient,
    this.userName,
    this.forPatient = false,
  });

  final ApiClient apiClient;
  final String? userName;

  /// Suggestions et ton adaptés au patient plutôt qu'au soignant.
  final bool forPatient;

  @override
  State<KoraiChatbotScreen> createState() => _KoraiChatbotScreenState();
}

class _KoraiChatbotScreenState extends State<KoraiChatbotScreen> {
  late final KoraiChatbotCubit _chatbotCubit;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const _proSuggestions = [
    'Quels sont les signes d’une otite moyenne ?',
    'Comment bien utiliser l’otoscope ?',
    'Comment soulager une otalgie en urgence ?',
    'Quand orienter vers un ORL ?',
    'Quelle est la fiabilité du diagnostic IA ?',
  ];

  static const _patientSuggestions = [
    'Qu’est-ce qu’une otite ?',
    'Comment soulager une douleur à l’oreille ?',
    'Quand faut-il consulter en urgence ?',
    'Comment nettoyer ses oreilles sans risque ?',
  ];

  @override
  void initState() {
    super.initState();
    _chatbotCubit = KoraiChatbotCubit(repository: ChatRepository(widget.apiClient));
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
          duration: KMotion.of(context, KMotion.slow),
          curve: KMotion.enter,
        );
      }
    });
  }

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty || _chatbotCubit.state.isSending) return;
    _inputController.clear();
    await _chatbotCubit.sendMessage(text);
  }

  String get _firstName {
    final parts = (widget.userName ?? '').trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? '' : parts.first;
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return BlocConsumer<KoraiChatbotCubit, KoraiChatbotState>(
      bloc: _chatbotCubit,
      listener: (context, state) => _scrollToBottom(),
      builder: (context, state) {
        return Scaffold(
          drawer: _buildConversationDrawer(state),
          appBar: AppBar(
            leading: Builder(
              builder: (context) => IconButton(
                tooltip: 'Mes conversations',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                _AssistantAvatar(size: 36),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assistant Korai', style: context.text.titleMedium),
                    Text('Réponses générées par l’IA', style: context.text.bodySmall?.copyWith(color: k.aquaInk)),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Nouvelle conversation',
                onPressed: state.isSending ? null : _chatbotCubit.createNewConversation,
                icon: const Icon(Icons.add_comment_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              if (state.errorBanner != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xs, KSpace.gutter, 0),
                  child: KBanner(
                    tone: KTone.warning,
                    message: state.errorBanner!,
                    actionLabel: 'Fermer',
                    onAction: _chatbotCubit.dismissError,
                  ),
                ),
              Expanded(
                child: state.isLoadingConversations && state.messages.isEmpty
                    ? const KLoadingView(message: 'Chargement de vos conversations…')
                    : state.showWelcome
                        ? _buildWelcomePanel()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.md, KSpace.gutter, KSpace.md),
                            itemCount: state.messages.length + (state.hasMoreMessages ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (state.hasMoreMessages && index == 0) {
                                return Center(
                                  child: TextButton.icon(
                                    onPressed: state.isLoadingMessages ? null : _chatbotCubit.loadOlderMessages,
                                    icon: state.isLoadingMessages
                                        ? const SizedBox(
                                            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.history_rounded),
                                    label: Text(
                                        state.isLoadingMessages ? 'Chargement…' : 'Afficher les messages précédents'),
                                  ),
                                );
                              }
                              final message = state.messages[index - (state.hasMoreMessages ? 1 : 0)];
                              return _MessageBubble(
                                message: message,
                                retrying: state.retryingMessageId == message.id,
                                canRetry: state.retryingMessageId == null,
                                onRetry: () => _chatbotCubit.retryMessage(message),
                              );
                            },
                          ),
              ),
              if (state.isSending) const _TypingIndicator(),
              _buildInputBar(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConversationDrawer(KoraiChatbotState state) {
    final k = context.k;
    final conversations = state.visibleConversations;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.sm, KSpace.sm, KSpace.xs),
              child: Row(
                children: [
                  Expanded(child: Text('Mes conversations', style: context.text.titleLarge)),
                  IconButton.filledTonal(
                    tooltip: 'Nouvelle conversation',
                    onPressed: () {
                      Navigator.of(context).pop();
                      _chatbotCubit.createNewConversation();
                    },
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: k.line),
            if (state.isLoadingConversations) LinearProgressIndicator(minHeight: 2, color: k.brand),
            Expanded(
              child: conversations.isEmpty
                  ? const KEmptyView(
                      icon: Icons.forum_outlined,
                      title: 'Aucune conversation',
                      message: 'Vos échanges avec l’assistant seront conservés ici.',
                      compact: true,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: KSpace.xs),
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final selected = state.activeConversation?.id == conversation.id;
                        return ListTile(
                          selected: selected,
                          selectedTileColor: k.lagoon,
                          selectedColor: k.brand,
                          leading: Icon(
                            selected ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                            color: selected ? k.brand : k.inkMuted,
                          ),
                          title: Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall,
                          ),
                          subtitle: Text(_relativeDate(conversation.lastMessageAt), maxLines: 1),
                          trailing: IconButton(
                            tooltip: 'Archiver la conversation',
                            onPressed: () async {
                              final ok = await showKConfirm(
                                context,
                                title: 'Archiver la conversation ?',
                                message: '« ${conversation.title} » disparaîtra de la liste.',
                                confirmLabel: 'Archiver',
                              );
                              if (ok) _chatbotCubit.archiveConversation(conversation);
                            },
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
    final k = context.k;
    final suggestions = widget.forPatient ? _patientSuggestions : _proSuggestions;
    return ListView(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.xl, KSpace.gutter, KSpace.lg),
      children: [
        const Center(child: _AssistantAvatar(size: 64)),
        const SizedBox(height: KSpace.md),
        Text(
          _firstName.isEmpty ? 'Bonjour' : 'Bonjour $_firstName',
          textAlign: TextAlign.center,
          style: context.text.headlineSmall,
        ),
        const SizedBox(height: KSpace.xs),
        Text(
          widget.forPatient
              ? 'Posez une question sur la santé de l’oreille. L’assistant informe, il ne remplace pas une consultation.'
              : 'Posez une question ORL générale. Vos conversations sont conservées dans le menu en haut à gauche.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: k.inkMuted),
        ),
        const SizedBox(height: KSpace.lg),
        Text('Pour commencer', style: context.text.labelMedium?.copyWith(color: k.inkMuted)),
        const SizedBox(height: KSpace.xs),
        for (final suggestion in suggestions) ...[
          KCard(
            onTap: () => _handleSendMessage(suggestion),
            padding: const EdgeInsets.symmetric(horizontal: KSpace.md, vertical: KSpace.sm),
            child: Row(
              children: [
                Expanded(child: Text(suggestion, style: context.text.bodyMedium)),
                Icon(Icons.north_east_rounded, size: 18, color: k.brand),
              ],
            ),
          ),
          const SizedBox(height: KSpace.xs),
        ],
      ],
    );
  }

  Widget _buildInputBar(KoraiChatbotState state) {
    final k = context.k;
    return Container(
      padding: const EdgeInsets.fromLTRB(KSpace.gutter, KSpace.sm, KSpace.sm, KSpace.sm),
      decoration: BoxDecoration(color: k.surface, border: Border(top: BorderSide(color: k.line))),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                onSubmitted: _handleSendMessage,
                enabled: !state.isSending,
                decoration: InputDecoration(
                  hintText: state.isSending ? 'L’assistant rédige sa réponse…' : 'Votre question…',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KRadius.pill), borderSide: BorderSide(color: k.line)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KRadius.pill), borderSide: BorderSide(color: k.line)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KRadius.pill),
                      borderSide: BorderSide(color: k.brand, width: 2)),
                  disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KRadius.pill), borderSide: BorderSide(color: k.line)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  fillColor: k.mist,
                ),
              ),
            ),
            const SizedBox(width: KSpace.xs),
            IconButton.filled(
              tooltip: 'Envoyer',
              style: IconButton.styleFrom(
                backgroundColor: k.brand,
                foregroundColor: k.onBrand,
                minimumSize: const Size(48, 48),
              ),
              onPressed: state.isSending ? null : () => _handleSendMessage(_inputController.text),
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'à l’instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: k.aquaBg, shape: BoxShape.circle),
      child: Icon(Icons.auto_awesome_rounded, color: k.aquaInk, size: size * 0.5),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.retrying, required this.canRetry, required this.onRetry});

  final ChatMessage message;
  final bool retrying;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final user = message.isUser;
    final failed = message.isFailed;
    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';
    final textColor = user ? k.onBrand : (failed ? k.dangerInk : k.ink);

    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: _BubbleFrame(
        user: user,
        accent: failed ? k.danger : k.aqua,
        background: user ? k.brand : (failed ? k.dangerBg : k.surface),
        maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        margin: const EdgeInsets.only(bottom: KSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(message.content, style: context.text.bodyLarge?.copyWith(color: textColor, height: 1.45)),
            if (message.isAssistant && !failed && message.sources.isNotEmpty) ...[
              const SizedBox(height: KSpace.xs),
              Text('Sources', style: context.text.labelSmall?.copyWith(color: k.inkMuted)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in message.sources.take(4))
                    Container(
                      constraints: const BoxConstraints(maxWidth: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: k.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_outlined, size: 14, color: k.inkMuted),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              s,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(color: k.inkMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (failed && message.isAssistant) ...[
              const SizedBox(height: KSpace.xs),
              TextButton.icon(
                onPressed: canRetry ? onRetry : null,
                icon: retrying
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retrying ? 'Nouvel essai…' : 'Réessayer'),
              ),
            ],
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                message.isPending ? 'Envoi…' : time,
                style: context.text.labelSmall?.copyWith(
                  color: user ? k.onBrand.withValues(alpha: 0.7) : k.inkMuted,
                  fontFamily: KFonts.mono,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        liveRegion: true,
        label: 'L’assistant rédige sa réponse',
        child: _BubbleFrame(
          user: false,
          accent: k.aqua,
          background: k.surface,
          margin: const EdgeInsets.fromLTRB(KSpace.gutter, 0, KSpace.gutter, KSpace.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: k.aqua)),
              const SizedBox(width: 8),
              Text('L’assistant rédige sa réponse…', style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bulle de conversation. Réponses de l'assistant : filet coloré à gauche
/// (aqua = IA), dessiné à part car un bord arrondi n'accepte qu'une couleur.
class _BubbleFrame extends StatelessWidget {
  const _BubbleFrame({
    required this.user,
    required this.accent,
    required this.background,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.maxWidth,
  });

  final bool user;
  final Color accent;
  final Color background;
  final Widget child;
  final EdgeInsetsGeometry margin;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(user ? 18 : 4),
      bottomRight: Radius.circular(user ? 4 : 18),
    );
    return Container(
      margin: margin,
      constraints: maxWidth == null ? null : BoxConstraints(maxWidth: maxWidth!),
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: user ? null : Border.all(color: k.line),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          decoration: user ? null : BoxDecoration(border: Border(left: BorderSide(color: accent, width: 3))),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: child,
        ),
      ),
    );
  }
}
