// lib/screens/chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import '../core/user_provider.dart';
import 'edit_profile_screen.dart';
import 'edit_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Open ChatScreen with a slide-up animation (like a bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────
Route<void> chatScreenRoute({
  required int     providerId,
  required String  providerName,
  String?          providerCategory,
  String?          providerCity,
}) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => ChatScreen(
      providerId:       providerId,
      providerName:     providerName,
      providerCategory: providerCategory,
      providerCity:     providerCity,
    ),
    transitionDuration:        const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (_, animation, __, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0, 1), // starts off-screen below
        end:   Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve:  Curves.easeOutCubic,
      ));
      return SlideTransition(position: slide, child: child);
    },
  );
}

class ChatScreen extends StatefulWidget {
  final int     providerId;
  final String  providerName;
  final String? providerCategory;
  final String? providerCity;

  const ChatScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    this.providerCategory,
    this.providerCity,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool   _loading  = true;
  bool   _sending  = false;
  int    _userId   = 0;
  String _userRole = 'client';
  String _fullName = '';
  Timer? _pollTimer;

  // Animation for the white chat card sliding up
  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 480),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve:  Curves.easeOutCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _slideCtrl,
      curve:  const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _slideCtrl.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final session = await UserSession.load();
    if (!mounted) return;
    setState(() {
      _userId   = session['id']        ?? 0;
      _userRole = session['role']      ?? 'client';
      _fullName    = session['full_name']    ?? '';
    });
    await _loadMessages();
    await _markRead();
    // Start the slide-up animation after messages load
    _slideCtrl.forward();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 4), (_) => _loadMessages());
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ApiService.getConversation(
        clientId:   _userRole == 'client' ? _userId : 0,
        providerId: widget.providerId,
      );
      if (!mounted) return;
      setState(() { _messages = data; _loading = false; });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await ApiService.markMessagesRead(
        clientId:   _userRole == 'client' ? _userId : 0,
        providerId: widget.providerId,
        readerType: _userRole,
      );
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await ApiService.sendMessage(
        senderId:     _userId,
        senderType:   _userRole,
        receiverId:   widget.providerId,
        receiverType: 'provider',
        content:      text,
      );
      await _loadMessages();
    } catch (_) {
      if (mounted) _msgCtrl.text = text;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve:    Curves.easeOut,
        );
      }
    });
  }

  bool _isMe(Map<String, dynamic> msg) =>
      msg['sender_id'] == _userId && msg['sender_type'] == _userRole;

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  bool _showDateSep(int i) {
    if (i == 0) return true;
    final a = DateTime.tryParse(_messages[i]['created_at'] ?? '')?.toLocal();
    final b = DateTime.tryParse(_messages[i - 1]['created_at'] ?? '')?.toLocal();
    if (a == null || b == null) return false;
    return !(a.year == b.year && a.month == b.month && a.day == b.day);
  }

  String _dateLabel(String? iso, LanguageProvider lang) {
    if (iso == null) return '';
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day)
        return lang.t('today');
      final yes = now.subtract(const Duration(days: 1));
      if (dt.year == yes.year && dt.month == yes.month && dt.day == yes.day)
        return lang.t('yesterday');
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final lang     = context.watch<LanguageProvider>();
    final subtitle = [
      if (widget.providerCategory != null &&
          widget.providerCategory!.isNotEmpty) widget.providerCategory!,
      if (widget.providerCity != null &&
          widget.providerCity!.isNotEmpty)     widget.providerCity!,
    ].join(' · ');

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [

            // ── Background: same as conversations page ────────────────
            Positioned.fill(
              child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.75),
                      Colors.white.withOpacity(0.97),
                    ],
                  ),
                ),
              ),
            ),

            Column(
              children: [

                // ── Fixed header: identical to conversations page ───────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo + name + avatar row
                        Row(
                          children: [
                            Image.asset('assets/images/aloo_logo.png',
                                height: 60, fit: BoxFit.contain),
                            const Spacer(),
                            if (_fullName.isNotEmpty)
                              Text(
                                _fullName,
                                style: const TextStyle(
                                  fontSize:   14,
                                  fontWeight: FontWeight.w800,
                                  color:      Colors.white,
                                ),
                              ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () async {
                                final updated = await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                                if (updated == true && mounted) {
                                  await context.read<UserProvider>().load();
                                }
                              },
                              child: Consumer<UserProvider>(
                                builder: (_, user, __) => UserAvatar(
                                  avatarIndex: user.avatarIndex,
                                  photoPath:   user.photoPath,
                                  size:        40,
                                  showBorder:  true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // ── White chat card slides up from below ───────────────
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Container(
                        decoration: const BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24)),
                          boxShadow: [
                            BoxShadow(
                              color:      Color(0x202A5298),
                              blurRadius: 24,
                              offset:     Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [

                            // ── Provider row inside the white card ──────
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                  8, 12, 12, 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade100,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Back arrow
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.pop(context),
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Color(0xFF1E293B),
                                      size:  20,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                  ),

                                  // Provider avatar
                                  Container(
                                    width: 44, height: 44,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        widget.providerName.isNotEmpty
                                            ? widget.providerName[0]
                                                .toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize:   19,
                                          fontWeight: FontWeight.w800,
                                          color:      Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Name + subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.providerName,
                                          style: const TextStyle(
                                            fontSize:   15,
                                            fontWeight: FontWeight.w800,
                                            color:      Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (subtitle.isNotEmpty)
                                          Text(
                                            subtitle,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:    Color(0xFF64748B),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // 3-dot
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey.shade100,
                                    ),
                                    child: const Icon(
                                        Icons.more_horiz_rounded,
                                        color: Color(0xFF64748B),
                                        size:  20),
                                  ),
                                ],
                              ),
                            ),

                            // ── Messages ────────────────────────────────
                            Expanded(
                              child: _loading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                          color:       Color(0xFF2A5298),
                                          strokeWidth: 2.5))
                                  : _messages.isEmpty
                                      ? _EmptyChat(
                                          name: widget.providerName,
                                          lang: lang)
                                      : GestureDetector(
                                          onTap: () => FocusScope.of(
                                                  context)
                                              .unfocus(),
                                          child: ListView.builder(
                                            controller: _scrollCtrl,
                                            physics: const BouncingScrollPhysics(),
                                            padding: const EdgeInsets
                                                .fromLTRB(16, 12, 16, 8),
                                            itemCount:
                                                _messages.length,
                                            itemBuilder: (_, i) {
                                              final msg  = _messages[i];
                                              final isMe = _isMe(msg);
                                              return Column(children: [
                                                if (_showDateSep(i))
                                                  _DateSep(
                                                    label: _dateLabel(
                                                      msg['created_at']
                                                          as String?,
                                                      lang,
                                                    ),
                                                  ),
                                                _Bubble(
                                                  content: msg['content']
                                                          as String? ??
                                                      '',
                                                  isMe:   isMe,
                                                  time:   _formatTime(
                                                      msg['created_at']
                                                          as String?),
                                                  isRead: msg['is_read'] ==
                                                      true,
                                                  lang:   lang,
                                                ),
                                              ]);
                                            },
                                          ),
                                        ),
                            ),

                            // ── Input bar ───────────────────────────────
                            _InputBar(
                              controller: _msgCtrl,
                              sending:    _sending,
                              onSend:     _send,
                              lang:       lang,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUBBLE
// ─────────────────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final String           content;
  final bool             isMe;
  final String           time;
  final bool             isRead;
  final LanguageProvider lang;

  const _Bubble({
    required this.content,
    required this.isMe,
    required this.time,
    required this.isRead,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFFCBD5E1)),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:  Text(lang.t('message_copied')),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: Container(
                constraints: BoxConstraints(
                    maxWidth:
                        MediaQuery.of(context).size.width * 0.72),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          begin:  Alignment.topLeft,
                          end:    Alignment.bottomRight,
                          colors: [
                            Color(0xFF4B9EFF),
                            Color(0xFF2A5298)
                          ],
                        )
                      : null,
                  color: isMe ? null : const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(20),
                    topRight:    const Radius.circular(20),
                    bottomLeft:  Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4  : 20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 15,
                        color:    isMe
                            ? Colors.white
                            : const Color(0xFF1E293B),
                        height:   1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color:    isMe
                                ? Colors.white.withOpacity(0.70)
                                : Colors.grey.shade400,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size:  13,
                            color: Colors.white
                                .withOpacity(isRead ? 0.90 : 0.55),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE SEPARATOR
// ─────────────────────────────────────────────────────────────────────────────

class _DateSep extends StatelessWidget {
  final String label;
  const _DateSep({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
              child:
                  Divider(color: Colors.grey.shade200, thickness: 1)),
          Container(
            margin:  const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color:        Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                  fontSize:   12,
                  color:      Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
              child:
                  Divider(color: Colors.grey.shade200, thickness: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INPUT BAR
// ─────────────────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool                  sending;
  final VoidCallback          onSend;
  final LanguageProvider      lang;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color:   Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color:        const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    controller:      controller,
                    maxLines:        null,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText:  lang.t('write_message'),
                      hintStyle: const TextStyle(
                          fontSize: 15, color: Color(0xFFADB5BD)),
                      border:         InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: sending ? null : onSend,
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sending
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF2A5298),
                    boxShadow: sending
                        ? []
                        : [
                            BoxShadow(
                              color: const Color(0xFF2A5298)
                                  .withOpacity(0.40),
                              blurRadius: 12,
                              offset:     const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: sending
                      ? const Center(
                          child: SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color:       Colors.white),
                          ))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY CHAT
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final String           name;
  final LanguageProvider lang;
  const _EmptyChat({required this.name, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.waving_hand_rounded,
                color: Color(0xFF2A5298), size: 38),
          ),
          const SizedBox(height: 18),
          Text(
            '${lang.t('start_chat_with')} $name',
            style: const TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.w600,
              color:      Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            lang.t('send_first_message'),
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}