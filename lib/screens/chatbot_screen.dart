import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../services/api_services.dart';

class ChatbotScreen extends StatefulWidget {
  final String userRole;
  const ChatbotScreen({super.key, required this.userRole});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<_BotMessage> _messages = [];
  bool _welcomeAdded = false;

  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_welcomeAdded) return;
    _messages.add(_BotMessage(text: _t('welcome'), isUser: false));
    _welcomeAdded = true;
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_BotMessage(text: text, isUser: true));
      _sending = true;
      _inputCtrl.clear();
    });
    _scrollToBottom();

    try {
      final res = await ApiService.getChatbotReply(
        message: text,
        userRole: widget.userRole,
        languageCode: context.read<LanguageProvider>().langCode,
      );
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final reply = (data['reply'] as String? ?? '').trim();
      setState(() {
        _messages.add(_BotMessage(
          text: reply.isEmpty ? _t('empty_reply') : reply,
          isUser: false,
        ));
      });
    } catch (_) {
      setState(() {
        _messages.add(_BotMessage(
          text: _t('unavailable'),
          isUser: false,
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('title')),
        backgroundColor: const Color(0xFF1A3A6B),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? const Color(0xFF1A3A6B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                        bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            msg.isUser ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: _t('hint'),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _sending
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF1A3A6B),
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _t(String key) {
    final code = context.read<LanguageProvider>().langCode;
    const map = {
      'title': {
        'en': 'Assistant',
        'fr': 'Assistant',
        'ar': 'المساعد',
      },
      'welcome': {
        'en': 'Hello! I am your ALOO assistant. Ask me about booking, pricing, or providers.',
        'fr': 'Bonjour ! Je suis votre assistant ALOO. Posez-moi vos questions sur reservation, prix ou prestataires.',
        'ar': 'مرحبا! انا مساعد ALOO. اسالني عن الحجز او الاسعار او مزودي الخدمة.',
      },
      'hint': {
        'en': 'Ask the assistant...',
        'fr': 'Posez votre question...',
        'ar': 'اكتب سؤالك...',
      },
      'empty_reply': {
        'en': 'I could not generate a reply right now.',
        'fr': 'Je ne peux pas generer une reponse pour le moment.',
        'ar': 'لا استطيع توليد رد حاليا.',
      },
      'unavailable': {
        'en': 'Assistant is unavailable right now. Please try again.',
        'fr': 'Le chatbot est indisponible pour le moment. Reessayez.',
        'ar': 'المساعد غير متاح حاليا. حاول مرة اخرى.',
      },
    };
    return map[key]?[code] ?? map[key]?['en'] ?? key;
  }
}

class _BotMessage {
  final String text;
  final bool isUser;
  const _BotMessage({required this.text, required this.isUser});
}
