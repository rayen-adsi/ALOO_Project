// lib/screens/chat_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import '../core/user_provider.dart';
import 'edit_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Route helper
// ─────────────────────────────────────────────────────────────────────────────
Route<void> chatScreenRoute({
  required int providerId, required String providerName,
  String? providerCategory, String? providerCity,
  int? clientId, String? clientName,
}) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => ChatScreen(
      providerId: providerId, providerName: providerName,
      providerCategory: providerCategory, providerCity: providerCity,
      clientId: clientId, clientName: clientName),
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (_, animation, __, child) {
      final slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: slide, child: child);
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Message type prefixes
// ─────────────────────────────────────────────────────────────────────────────
const String _offerPrefix = 'OFFER_JSON:';
const String _mediaPrefix = 'MEDIA_JSON:';

bool _isOfferMessage(String c) => c.startsWith(_offerPrefix);
bool _isMediaMessage(String c) => c.startsWith(_mediaPrefix);

Map<String, dynamic>? _parseOffer(String c) {
  if (!_isOfferMessage(c)) return null;
  try { return jsonDecode(c.substring(_offerPrefix.length)); } catch (_) { return null; }
}
Map<String, dynamic>? _parseMedia(String c) {
  if (!_isMediaMessage(c)) return null;
  try { return jsonDecode(c.substring(_mediaPrefix.length)); } catch (_) { return null; }
}
String _encodeOffer(Map<String, dynamic> o) => '$_offerPrefix${jsonEncode(o)}';
String _encodeMedia(Map<String, dynamic> m) => '$_mediaPrefix${jsonEncode(m)}';

// ─────────────────────────────────────────────────────────────────────────────
// ChatScreen
// ─────────────────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final int providerId; final String providerName;
  final String? providerCategory, providerCity;
  final int? clientId; final String? clientName;
  const ChatScreen({super.key, required this.providerId, required this.providerName,
    this.providerCategory, this.providerCity, this.clientId, this.clientName});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _botMessages = [];
  bool _loading = true, _sending = false;
  bool _botThinking = false;
  int _userId = 0; String _userRole = 'client', _fullName = '';
  Timer? _pollTimer;
  int _actualClientId = 0, _actualProviderId = 0;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _init();
  }

  @override
  void dispose() { _pollTimer?.cancel(); _slideCtrl.dispose(); _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _init() async {
    final s = await UserSession.load();
    if (!mounted) return;
    setState(() { _userId = s['id'] ?? 0; _userRole = s['role'] ?? 'client'; _fullName = s['full_name'] ?? ''; });
    if (_userRole == 'client') { _actualClientId = _userId; _actualProviderId = widget.providerId; }
    else { _actualProviderId = _userId; _actualClientId = widget.clientId ?? widget.providerId; }
    await _loadMessages(); await _markRead(); _slideCtrl.forward();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages());
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ApiService.getConversation(clientId: _actualClientId, providerId: _actualProviderId);
      if (!mounted) return;
      final merged = [...data, ..._botMessages];
      merged.sort((a, b) {
        final da = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return da.compareTo(db);
      });
      setState(() { _messages = merged; _loading = false; }); _scrollToBottom();
    } catch (_) { if (!mounted) return; setState(() => _loading = false); }
  }

  Future<void> _markRead() async {
    try { await ApiService.markMessagesRead(clientId: _actualClientId, providerId: _actualProviderId, readerType: _userRole); } catch (_) {}
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true); _msgCtrl.clear();
    try {
      final int rid; final String rt;
      if (_userRole == 'client') { rid = _actualProviderId; rt = 'provider'; }
      else { rid = _actualClientId; rt = 'client'; }
      await ApiService.sendMessage(senderId: _userId, senderType: _userRole, receiverId: rid, receiverType: rt, content: text);
      await _loadMessages();
    } catch (_) { if (mounted) _msgCtrl.text = text; }
    finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _sendOffer(Map<String, dynamic> d) async {
    setState(() => _sending = true);
    try {
      await ApiService.sendMessage(senderId: _userId, senderType: _userRole,
        receiverId: _actualClientId, receiverType: 'client', content: _encodeOffer(d));
      await _loadMessages();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _respondToOffer(Map<String, dynamic> orig, String status) async {
    setState(() => _sending = true);
    try {
      final updated = Map<String, dynamic>.from(orig)..['status'] = status;
      await ApiService.sendMessage(senderId: _userId, senderType: _userRole,
        receiverId: _actualProviderId, receiverType: 'provider', content: _encodeOffer(updated));
      await _loadMessages();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  // ── Media sending ─────────────────────────────────────────────────────
  bool _uploading = false;

  Future<void> _sendMedia(String filePath, String type) async {
    final lang = context.read<LanguageProvider>();
    setState(() { _sending = true; _uploading = true; });
    try {
      final res = await ApiService.uploadChatMedia(
        userId: _userId, role: _userRole, filePath: filePath);

      if (res['success'] == true && res['photo_url'] != null && (res['photo_url'] as String).isNotEmpty) {
        final mediaMsg = _encodeMedia({
          'type': type,
          'url':  res['photo_url'],
        });
        final int rid; final String rt;
        if (_userRole == 'client') { rid = _actualProviderId; rt = 'provider'; }
        else { rid = _actualClientId; rt = 'client'; }
        await ApiService.sendMessage(senderId: _userId, senderType: _userRole,
          receiverId: rid, receiverType: rt, content: mediaMsg);
        await _loadMessages();
      } else {
        // Upload failed — show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang.t('media_upload_failed')),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.t('media_upload_failed')),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating));
      }
    }
    if (mounted) setState(() { _sending = false; _uploading = false; });
  }

  void _showMediaPicker() {
    final lang = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 20),
          Text(lang.t('send_media'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B))),
          const SizedBox(height: 20),
          _MediaOption(icon: Icons.camera_alt_rounded, label: lang.t('take_photo'), color: const Color(0xFF2A5298),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
          const SizedBox(height: 10),
          _MediaOption(icon: Icons.photo_library_rounded, label: lang.t('choose_from_gallery'), color: const Color(0xFF10B981),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
        ]),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1200);
      if (picked != null) _sendMedia(picked.path, 'image');
    } catch (_) {}
  }

  Future<void> _askBot() async {
    final lang = context.read<LanguageProvider>();
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _botThinking) {
      if (text.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.t('bot_enter_question')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _botThinking = true);
    try {
      final res = await ApiService.getChatbotReply(
        message: text,
        userRole: _userRole,
        languageCode: lang.langCode,
      );
      if (!mounted) return;
      if (res['success'] == true && (res['reply'] as String).isNotEmpty) {
        _msgCtrl.clear();
        final botMsg = <String, dynamic>{
          'id': -DateTime.now().millisecondsSinceEpoch,
          'sender_id': -1,
          'sender_type': 'bot',
          'receiver_id': _userId,
          'receiver_type': _userRole,
          'content': res['reply'] as String,
          'is_read': true,
          'created_at': DateTime.now().toIso8601String(),
        };
        setState(() {
          _botMessages.add(botMsg);
          _messages = [..._messages, botMsg];
        });
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] as String? ?? lang.t('bot_unavailable')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.t('bot_unavailable')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
    if (mounted) setState(() => _botThinking = false);
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    });
  }
  bool _isMe(Map<String, dynamic> msg) => msg['sender_id'] == _userId && msg['sender_type'] == _userRole;
  String _fmtTime(String? iso) { if (iso == null) return ''; try { final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'; } catch (_) { return ''; } }
  bool _showDateSep(int i) { if (i == 0) return true;
    final a = DateTime.tryParse(_messages[i]['created_at'] ?? '')?.toLocal();
    final b = DateTime.tryParse(_messages[i-1]['created_at'] ?? '')?.toLocal();
    if (a == null || b == null) return false;
    return !(a.year == b.year && a.month == b.month && a.day == b.day); }
  String _dateLabel(String? iso, LanguageProvider lang) { if (iso == null) return '';
    try { final dt = DateTime.parse(iso).toLocal(); final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return lang.t('today');
      final y = now.subtract(const Duration(days: 1));
      if (dt.year == y.year && dt.month == y.month && dt.day == y.day) return lang.t('yesterday');
      return '${dt.day}/${dt.month}/${dt.year}'; } catch (_) { return ''; } }

  String _getLatestOfferStatus(Map<String, dynamic> offer) {
    final d = offer['description'] ?? ''; final dt = offer['date'] ?? ''; final t = offer['time'] ?? '';
    String s = offer['status'] ?? 'pending';
    for (final msg in _messages) { final p = _parseOffer(msg['content'] as String? ?? '');
      if (p != null && p['description'] == d && p['date'] == dt && p['time'] == t) s = p['status'] ?? 'pending'; }
    return s;
  }

  void _showCreateOffer() {
    final lang = context.read<LanguageProvider>();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _CreateOfferSheet(lang: lang, onSend: (d) { Navigator.pop(context); _sendOffer(d); }));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final String chatPartnerName; final String subtitle;
    if (_userRole == 'client') { chatPartnerName = widget.providerName;
      subtitle = [if (widget.providerCategory?.isNotEmpty == true) widget.providerCategory!,
        if (widget.providerCity?.isNotEmpty == true) widget.providerCity!].join(' · ');
    } else { chatPartnerName = widget.clientName ?? widget.providerName; subtitle = ''; }

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          Positioned.fill(child: Image.asset('assets/images/bg.png', fit: BoxFit.cover)),
          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.75), Colors.white.withOpacity(0.97)])))),
          Column(children: [
            // Header
            SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Image.asset('assets/images/aloo_logo.png', height: 60, fit: BoxFit.contain), const Spacer(),
                  if (_fullName.isNotEmpty) Text(_fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(width: 10),
                  GestureDetector(onTap: () async {
                    final u = await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                    if (u == true && mounted) await context.read<UserProvider>().load(); },
                    child: Consumer<UserProvider>(builder: (_, user, __) =>
                      UserAvatar(avatarIndex: user.avatarIndex, photoPath: user.photoPath, size: 40, showBorder: true))),
                ]),
                const SizedBox(height: 12),
              ]))),

            // Chat card
            Expanded(child: FadeTransition(opacity: _fadeAnim, child: SlideTransition(position: _slideAnim,
              child: Container(
                decoration: const BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Color(0x202A5298), blurRadius: 24, offset: Offset(0, -4))]),
                child: Column(children: [
                  // Partner row
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1))),
                    child: Row(children: [
                      IconButton(onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20), padding: const EdgeInsets.all(8)),
                      Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFCBD5E1)),
                        child: Center(child: Text(chatPartnerName.isNotEmpty ? chatPartnerName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(chatPartnerName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ])),
                      Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade100),
                        child: const Icon(Icons.more_horiz_rounded, color: Color(0xFF64748B), size: 20)),
                    ])),

                  // Messages
                  Expanded(child: Stack(
                    children: [
                      if (_loading)
                        const Center(child: CircularProgressIndicator(color: Color(0xFF2A5298), strokeWidth: 2.5))
                      else if (_messages.isEmpty)
                        _EmptyChat(name: chatPartnerName, lang: lang)
                      else
                        GestureDetector(onTap: () => FocusScope.of(context).unfocus(),
                          child: ListView.builder(controller: _scrollCtrl, physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), itemCount: _messages.length,
                            itemBuilder: (_, i) {
                              final msg = _messages[i]; final isMe = _isMe(msg);
                              final content = msg['content'] as String? ?? '';
                              final offer = _parseOffer(content);
                              final media = _parseMedia(content);
                              return Column(children: [
                                if (_showDateSep(i)) _DateSep(label: _dateLabel(msg['created_at'] as String?, lang)),
                                if (offer != null)
                                  _OfferCard(offer: offer, isMe: isMe, userRole: _userRole,
                                    latestStatus: _getLatestOfferStatus(offer),
                                    time: _fmtTime(msg['created_at'] as String?), lang: lang,
                                    onAccept: () => _respondToOffer(offer, 'accepted'),
                                    onRefuse: () => _respondToOffer(offer, 'refused'))
                                else if (media != null)
                                  _MediaBubble(media: media, isMe: isMe,
                                    time: _fmtTime(msg['created_at'] as String?),
                                    isRead: msg['is_read'] == true)
                                else
                                  _Bubble(content: content, isMe: isMe,
                                    time: _fmtTime(msg['created_at'] as String?),
                                    isRead: msg['is_read'] == true, lang: lang),
                              ]);
                            },
                          ),
                        ),

                      // ✅ Uploading overlay
                      if (_uploading)
                        Positioned.fill(
                          child: Container(
                            color: const Color(0xB3FFFFFF),
                            child: Center(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                const CircularProgressIndicator(color: Color(0xFF2A5298), strokeWidth: 3),
                                const SizedBox(height: 14),
                                Text(lang.t('uploading_media'),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2A5298))),
                              ]),
                            ),
                          ),
                        ),
                    ],
                  )),

                  // Input bar
                  _InputBar(controller: _msgCtrl, sending: _sending, botThinking: _botThinking, onSend: _send, onAskBot: _askBot, lang: lang,
                    isProvider: _userRole == 'provider', onCreateOffer: _userRole == 'provider' ? _showCreateOffer : null,
                    onAttach: _showMediaPicker),
                ])),
            ))),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA BUBBLE — shows image preview or video thumbnail
// ─────────────────────────────────────────────────────────────────────────────

class _MediaBubble extends StatelessWidget {
  final Map<String, dynamic> media;
  final bool isMe;
  final String time;
  final bool isRead;
  const _MediaBubble({required this.media, required this.isMe, required this.time, required this.isRead});

  @override
  Widget build(BuildContext context) {
    final type = media['type'] as String? ?? 'image';
    final url  = media['url']  as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 8, bottom: 2),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFCBD5E1)),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 16)),
            ],
            GestureDetector(
              onTap: () => _openMedia(context, url, type),
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(children: [
                    // Image or video thumbnail
                    if (type == 'image')
                      Image.network(url, fit: BoxFit.cover,
                        width: 220, height: 220,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(width: 220, height: 220, color: Colors.grey.shade100,
                            child: const Center(child: CircularProgressIndicator(color: Color(0xFF2A5298), strokeWidth: 2)));
                        },
                        errorBuilder: (_, __, ___) => Container(width: 220, height: 160, color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)))
                    else
                      Container(width: 220, height: 160, color: Colors.black87,
                        child: const Center(child: Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 56))),

                    // Time overlay
                    Positioned(bottom: 6, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(time, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
                          if (isMe) ...[
                            const SizedBox(width: 3),
                            Icon(isRead ? Icons.done_all_rounded : Icons.done_rounded, size: 12,
                              color: Colors.white.withOpacity(isRead ? 0.9 : 0.55)),
                          ],
                        ]),
                      ),
                    ),

                    // Video play icon overlay
                    if (type == 'video')
                      Positioned.fill(child: Center(
                        child: Container(width: 50, height: 50,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF2A5298), size: 30)))),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMedia(BuildContext ctx, String url, String type) {
    if (type == 'image') {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => _FullImageViewer(url: url)));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULL IMAGE VIEWER
// ─────────────────────────────────────────────────────────────────────────────

class _FullImageViewer extends StatelessWidget {
  final String url;
  const _FullImageViewer({required this.url});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(children: [
      Center(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
      SafeArea(child: Padding(padding: const EdgeInsets.all(8),
        child: IconButton(
          icon: Container(width: 36, height: 36,
            decoration: const BoxDecoration(color: Color(0x80000000), shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20)),
          onPressed: () => Navigator.pop(context)))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA OPTION ROW (for the bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _MediaOption extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _MediaOption({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.20), width: 1)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
        const Spacer(),
        Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5), size: 14),
      ])));
}

// ─────────────────────────────────────────────────────────────────────────────
// OFFER CARD (unchanged from before)
// ─────────────────────────────────────────────────────────────────────────────

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer; final bool isMe; final String userRole, latestStatus, time;
  final LanguageProvider lang; final VoidCallback onAccept, onRefuse;
  const _OfferCard({required this.offer, required this.isMe, required this.userRole,
    required this.latestStatus, required this.time, required this.lang,
    required this.onAccept, required this.onRefuse});

  @override
  Widget build(BuildContext context) {
    final desc = offer['description'] as String? ?? '';
    final date = offer['date'] as String? ?? '';
    final oTime = offer['time'] as String? ?? '';
    final addr = offer['address'] as String? ?? '';
    final status = latestStatus;
    final bool isPending = status == 'pending';
    final bool isAccepted = status == 'accepted';

    Color sc; IconData si; String sl;
    if (isAccepted) { sc = const Color(0xFF10B981); si = Icons.check_circle_rounded; sl = lang.t('offer_accepted'); }
    else if (status == 'refused') { sc = const Color(0xFFEF4444); si = Icons.cancel_rounded; sl = lang.t('offer_refused'); }
    else { sc = const Color(0xFFF59E0B); si = Icons.schedule_rounded; sl = lang.t('offer_pending'); }

    return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF2A5298).withOpacity(0.15), width: 1.2),
            boxShadow: [BoxShadow(color: const Color(0xFF2A5298).withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(color: const Color(0xFF2A5298).withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(17))),
              child: Row(children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(
                  color: const Color(0xFF2A5298).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.handshake_rounded, color: Color(0xFF2A5298), size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Text(lang.t('service_offer'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2A5298)))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(si, color: sc, size: 12), const SizedBox(width: 4),
                    Text(sl, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
                  ])),
              ])),
            Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (desc.isNotEmpty) ...[Text(desc, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B), height: 1.4)), const SizedBox(height: 10)],
              if (date.isNotEmpty || oTime.isNotEmpty) _OfferInfoRow(icon: Icons.calendar_today_rounded, color: const Color(0xFF2A5298),
                text: [date, oTime].where((s) => s.isNotEmpty).join(' ${lang.t("at")} ')),
              if (addr.isNotEmpty) ...[const SizedBox(height: 6), _OfferInfoRow(icon: Icons.location_on_rounded, color: const Color(0xFFEF4444), text: addr)],
            ])),
            if (userRole == 'client' && isPending)
              Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 14), child: Row(children: [
                Expanded(child: _OfferButton(label: lang.t('refuse'), color: const Color(0xFFEF4444), icon: Icons.close_rounded, outlined: true, onTap: onRefuse)),
                const SizedBox(width: 10),
                Expanded(child: _OfferButton(label: lang.t('accept'), color: const Color(0xFF10B981), icon: Icons.check_rounded, outlined: false, onTap: onAccept)),
              ]))
            else
              Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 12), child: Align(alignment: Alignment.centerRight,
                child: Text(time, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)))),
          ]),
        )));
  }
}

class _OfferInfoRow extends StatelessWidget {
  final IconData icon; final Color color; final String text;
  const _OfferInfoRow({required this.icon, required this.color, required this.text});
  @override Widget build(BuildContext context) => Row(children: [
    Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, color: color, size: 14)),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF475569)))),
  ]);
}

class _OfferButton extends StatefulWidget {
  final String label; final Color color; final IconData icon; final bool outlined; final VoidCallback onTap;
  const _OfferButton({required this.label, required this.color, required this.icon, required this.outlined, required this.onTap});
  @override State<_OfferButton> createState() => _OfferButtonState();
}
class _OfferButtonState extends State<_OfferButton> {
  bool _p = false;
  @override Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _p = true),
    onTapUp: (_) { setState(() => _p = false); widget.onTap(); },
    onTapCancel: () => setState(() => _p = false),
    child: AnimatedContainer(duration: const Duration(milliseconds: 120), height: 40,
      decoration: BoxDecoration(
        color: widget.outlined ? (_p ? widget.color.withOpacity(0.08) : Colors.transparent) : (_p ? widget.color.withOpacity(0.85) : widget.color),
        borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.color, width: 1.5)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(widget.icon, size: 16, color: widget.outlined ? widget.color : Colors.white),
        const SizedBox(width: 6),
        Text(widget.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.outlined ? widget.color : Colors.white)),
      ])));
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE OFFER SHEET (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _CreateOfferSheet extends StatefulWidget {
  final LanguageProvider lang; final ValueChanged<Map<String, dynamic>> onSend;
  const _CreateOfferSheet({required this.lang, required this.onSend});
  @override State<_CreateOfferSheet> createState() => _CreateOfferSheetState();
}
class _CreateOfferSheetState extends State<_CreateOfferSheet> {
  final _descCtrl = TextEditingController(); final _addrCtrl = TextEditingController();
  DateTime? _date; TimeOfDay? _time;
  @override void dispose() { _descCtrl.dispose(); _addrCtrl.dispose(); super.dispose(); }
  String _fmtDate() { if (_date == null) return ''; return '${_date!.day.toString().padLeft(2,'0')}/${_date!.month.toString().padLeft(2,'0')}/${_date!.year}'; }
  String _fmtTime() { if (_time == null) return ''; return '${_time!.hour.toString().padLeft(2,'0')}:${_time!.minute.toString().padLeft(2,'0')}'; }
  Future<void> _pickDate() async { final p = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)),
    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
    builder: (c, ch) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF2A5298))), child: ch!));
    if (p != null) setState(() => _date = p); }
  Future<void> _pickTime() async { final p = await showTimePicker(context: context, initialTime: TimeOfDay.now(),
    builder: (c, ch) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF2A5298))), child: ch!));
    if (p != null) setState(() => _time = p); }
  void _submit() { if (_descCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(widget.lang.t('fill_all_fields')))); return; }
    widget.onSend({'description': _descCtrl.text.trim(), 'date': _fmtDate(), 'time': _fmtTime(), 'address': _addrCtrl.text.trim(), 'status': 'pending'}); }

  @override Widget build(BuildContext context) { final lang = widget.lang;
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 18),
          Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF2A5298).withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.handshake_rounded, color: Color(0xFF2A5298), size: 20)), const SizedBox(width: 12),
            Text(lang.t('create_offer'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B)))]),
          const SizedBox(height: 20),
          Text(lang.t('offer_description'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          TextField(controller: _descCtrl, maxLines: 3, style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            decoration: InputDecoration(hintText: lang.t('offer_description_hint'), hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true, fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2A5298), width: 1.5)),
              contentPadding: const EdgeInsets.all(14))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _PickerField(icon: Icons.calendar_today_rounded, label: _date != null ? _fmtDate() : lang.t('pick_date'), hasValue: _date != null, onTap: _pickDate)),
            const SizedBox(width: 12),
            Expanded(child: _PickerField(icon: Icons.access_time_rounded, label: _time != null ? _fmtTime() : lang.t('pick_time'), hasValue: _time != null, onTap: _pickTime)),
          ]),
          const SizedBox(height: 16),
          Text(lang.t('address'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          TextField(controller: _addrCtrl, style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            decoration: InputDecoration(hintText: lang.t('offer_address_hint'), hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(Icons.location_on_outlined, color: Colors.grey.shade400, size: 20), filled: true, fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2A5298), width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14))),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A5298), elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            label: Text(lang.t('send_offer'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            onPressed: _submit)),
        ])))); }
}

class _PickerField extends StatelessWidget {
  final IconData icon; final String label; final bool hasValue; final VoidCallback onTap;
  const _PickerField({required this.icon, required this.label, required this.hasValue, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasValue ? const Color(0xFF2A5298).withOpacity(0.4) : Colors.grey.shade200)),
      child: Row(children: [
        Icon(icon, size: 18, color: hasValue ? const Color(0xFF2A5298) : Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
          color: hasValue ? const Color(0xFF1E293B) : Colors.grey.shade400))),
      ])));
}

// ─────────────────────────────────────────────────────────────────────────────
// BUBBLE, DATE SEP, INPUT BAR, EMPTY CHAT
// ─────────────────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final String content; final bool isMe; final String time; final bool isRead; final LanguageProvider lang;
  const _Bubble({required this.content, required this.isMe, required this.time, required this.isRead, required this.lang});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (!isMe) Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 8, bottom: 2),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFCBD5E1)),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 16)),
      Flexible(child: GestureDetector(
        onLongPress: () { Clipboard.setData(ClipboardData(text: content));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('message_copied')), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating)); },
        child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            gradient: isMe ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4B9EFF), Color(0xFF2A5298)]) : null,
            color: isMe ? null : const Color(0xFFF0F4F8),
            borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMe ? 20 : 4), bottomRight: Radius.circular(isMe ? 4 : 20))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(content, style: TextStyle(fontSize: 15, color: isMe ? Colors.white : const Color(0xFF1E293B), height: 1.4)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(time, style: TextStyle(fontSize: 11, color: isMe ? Colors.white.withOpacity(0.70) : Colors.grey.shade400)),
              if (isMe) ...[const SizedBox(width: 4),
                Icon(isRead ? Icons.done_all_rounded : Icons.done_rounded, size: 13, color: Colors.white.withOpacity(isRead ? 0.90 : 0.55))],
            ]),
          ]))))]));
}

class _DateSep extends StatelessWidget {
  final String label; const _DateSep({required this.label});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(children: [Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
      Container(margin: const EdgeInsets.symmetric(horizontal: 12), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500))),
      Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1))]));
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller; final bool sending; final VoidCallback onSend;
  final bool botThinking; final VoidCallback onAskBot;
  final LanguageProvider lang; final bool isProvider; final VoidCallback? onCreateOffer;
  final VoidCallback? onAttach;
  const _InputBar({required this.controller, required this.sending, required this.onSend,
    required this.botThinking, required this.onAskBot, required this.lang, this.isProvider = false, this.onCreateOffer, this.onAttach});

  @override Widget build(BuildContext context) => Container(color: Colors.white,
    padding: const EdgeInsets.fromLTRB(8, 10, 16, 0),
    child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        // Offer button (provider only)
        if (isProvider && onCreateOffer != null) ...[
          GestureDetector(onTap: onCreateOffer,
            child: Container(width: 38, height: 38,
              decoration: BoxDecoration(color: const Color(0xFF2A5298).withOpacity(0.08), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A5298).withOpacity(0.2))),
              child: const Icon(Icons.handshake_rounded, color: Color(0xFF2A5298), size: 18))),
          const SizedBox(width: 6),
        ],
        // ✅ Attachment button (both roles)
        GestureDetector(onTap: onAttach,
          child: Container(width: 38, height: 38,
            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2))),
            child: const Icon(Icons.attach_file_rounded, color: Color(0xFF10B981), size: 18))),
        const SizedBox(width: 6),
        // Text input
        Expanded(child: Container(constraints: const BoxConstraints(maxHeight: 120),
          decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(30)),
          child: TextField(controller: controller, maxLines: null, textInputAction: TextInputAction.newline,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
            decoration: InputDecoration(hintText: lang.t('write_message'),
              hintStyle: const TextStyle(fontSize: 15, color: Color(0xFFADB5BD)),
              border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13))))),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Ask assistant',
          child: GestureDetector(onTap: botThinking ? null : onAskBot,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: botThinking ? const Color(0xFF94A3B8) : const Color(0xFF0EA5A4),
                boxShadow: botThinking
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF0EA5A4).withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: botThinking
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Send button
        GestureDetector(onTap: sending ? null : onSend,
          child: Container(width: 46, height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: sending ? const Color(0xFF94A3B8) : const Color(0xFF2A5298),
              boxShadow: sending ? [] : [BoxShadow(color: const Color(0xFF2A5298).withOpacity(0.40), blurRadius: 12, offset: const Offset(0, 4))]),
            child: sending
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)))
              : const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
      ]))));
}

class _EmptyChat extends StatelessWidget {
  final String name; final LanguageProvider lang;
  const _EmptyChat({required this.name, required this.lang});
  @override Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 80, height: 80, decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
      child: const Icon(Icons.waving_hand_rounded, color: Color(0xFF2A5298), size: 38)),
    const SizedBox(height: 18),
    Text('${lang.t('start_chat_with')} $name', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), textAlign: TextAlign.center),
    const SizedBox(height: 8),
    Text(lang.t('send_first_message'), style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
  ]));
}