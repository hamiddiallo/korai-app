import 'dart:async';
import 'package:flutter/material.dart';

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
}

class KoraiChatbotScreen extends StatefulWidget {
  const KoraiChatbotScreen({super.key, this.userName});

  final String? userName;

  @override
  State<KoraiChatbotScreen> createState() => _KoraiChatbotScreenState();
}

class _KoraiChatbotScreenState extends State<KoraiChatbotScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  // Preset Questions & Answers
  final Map<String, String> _qaDatabase = {
    "qu'est-ce que korai ?":
        "KORAI est votre assistant d'aide au diagnostic ORL intelligent. Il analyse les symptômes cliniques, les images d'otoscopie et les antécédents pour guider la décision clinique.",
    "comment utiliser l'otoscope ?":
        "Pour utiliser l'otoscope KORAI, connectez l'appareil en Wi-Fi à votre smartphone, accédez à la section 'Image ORL', puis prenez un cliché net du tympan en évitant les mouvements brusques.",
    "quels sont les signes d'une otite moyenne ?":
        "Une otite moyenne aiguë (OMA) se manifeste généralement par une otalgie intense, de la fièvre, une baisse d'audition, et un tympan congestif ou bombant à l'examen otoscopique.",
    "comment soulager une otalgie en urgence ?":
        "Pour calmer une douleur à l'oreille, il est recommandé de prendre un antalgique par voie orale (comme le paracétamol) selon la posologie. Évitez d'introduire des gouttes auriculaires sans avis médical si le tympan n'a pas été vérifié.",
    "quelle est la précision du diagnostic ia ?":
        "L'IA KORAI affiche une précision diagnostique supérieure à 92% sur la classification des principales pathologies tympaniques (otite moyenne, tympan sain, bouchon de cérumen). Cependant, l'analyse reste une aide à la décision et doit être validée par un praticien.",
  };

  final List<String> _suggestions = [
    "Qu'est-ce que KORAI ?",
    "Comment utiliser l'otoscope ?",
    "Quels sont les signes d'une otite moyenne ?",
    "Comment soulager une otalgie en urgence ?",
    "Quelle est la précision du diagnostic IA ?",
  ];

  @override
  void initState() {
    super.initState();
    // Add welcome message
    final name = widget.userName ?? 'Praticien';
    _messages.add(
      ChatMessage(
        text:
            "Bonjour $name ! Je suis KORAI, votre assistant virtuel ORL. Comment puis-je vous accompagner dans vos consultations aujourd'hui ?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
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

  void _handleSendMessage(String text) {
    if (text.trim().isEmpty) return;

    _inputController.clear();
    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    // Simulate AI response
    Timer(const Duration(seconds: 1), () {
      final normalizedQuery = text.trim().toLowerCase().replaceAll('?', '').trim();
      String response =
          "Je ne suis pas sûr de comprendre cette question clinique pour le moment. Mes réponses de test couvrent l'otoscope, l'otite moyenne, les otalgies ou les détails sur l'IA KORAI.";

      for (final entry in _qaDatabase.entries) {
        if (normalizedQuery.contains(entry.key) || entry.key.contains(normalizedQuery)) {
          response = entry.value;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: response,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isTyping = false;
        });
        _scrollToBottom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KORAI Chatbot',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                Row(
                  children: [
                    Icon(Icons.circle, color: Colors.green, size: 8),
                    SizedBox(width: 4),
                    Text(
                      'IA en ligne',
                      style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Typing Indicator
          if (_isTyping) _buildTypingIndicator(),

          // Suggestions Bar
          if (_messages.length == 1 && !_isTyping) _buildSuggestionsBar(),

          // Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildSuggestionsBar() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              side: BorderSide(color: Colors.indigo.shade100),
              label: Text(
                suggestion,
                style: TextStyle(color: Colors.indigo.shade700, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              onPressed: () => _handleSendMessage(suggestion),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.indigo.shade600 : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: message.isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : const Color(0xFF334155),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}",
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
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
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

  Widget _buildInputBar() {
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
                decoration: InputDecoration(
                  hintText: 'Posez une question à KORAI...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: () => _handleSendMessage(_inputController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
