// lib/screens/chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';

class ChatScreen extends StatefulWidget {
  final int    providerId;
  final String providerName;
  final String? providerCategory;

  const ChatScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    this.providerCategory,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool    _loading  = true;
  bool    _sending  = false;
  String  _userRole = 'client';
  int     _userId   = 0;   // the logged-in user's id
  int     _clientId = 0;   // always the client side of the conversation

  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final session = await UserSession.load();
    _userId   = session['id']   ?? 0;
    _userRole = session['role'] ?? 'client';

    // clientId is always the client side — if the user IS a client, it's their id
    // if the user is a provider, the clientId must come from outside (not supported here yet)
    if (_userRole == 'client') {
      _clientId = _userId;
    } else {
      // Provider opened chat — clientId passed via providerId field (swap logic not needed for now)
      _clientId = _userId;
    }

    await _loadMessages();
    await _markRead();

    _pollTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _loadMessages(silent: true));
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await ApiService.getConversation(
        clientId:   _clientId,
        providerId: widget.providerId,
      );
      if (!mounted) return;
      setState(() {
        _messages = data;
        _loading  = false;
      });
      if (data.isNotEmpty) _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead() async {
    if (_clientId == 0) return;
    await ApiService.markMessagesRead(
      clientId:   _clientId,
      providerId: widget.providerId,
      readerType: _userRole,
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending || _clientId == 0) return;

    _msgCtrl.clear();
    setState(() => _sending = true);

    // Optimistic UI
    final optimistic = {
      'id':            -1,
      'sender_id':     _userId,
      'sender_type':   _userRole,
      'receiver_id':   _userRole == 'client' ? widget.providerId : _clientId,
      'receiver_type': _userRole == 'client' ? 'provider' : 'client',
      'content':       text,
      'is_read':       false,
      'created_at':    DateTime.now().toIso8601String(),
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    final result = await ApiService.sendMessage(
      senderId:     _userId,
      senderType:   _userRole,
      receiverId:   _userRole == 'client' ? widget.providerId : _clientId,
      receiverType: _userRole == 'client' ? 'provider' : 'client',
      content:      text,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (result['success'] != true) {
      setState(() => _messages.removeLast());
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to send')));
    } else {
      _loadMessages(silent: true);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients &&
          _scrollCtrl.position.maxScrollExtent > 0) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isMine(Map<String, dynamic> msg) {
    return msg['sender_id'] == _userId &&
           msg['sender_type'] == _userRole;
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h  = dt.hour.toString().padLeft(2, '0');
      final m  = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A3A6B),
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          title: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.providerName,
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                  if (widget.providerCategory != null)
                    Text(widget.providerCategory!,
                        style: TextStyle(fontSize: 11,
                            color: Colors.white.withOpacity(0.7))),
                ],
              ),
            ],
          ),
        ),

        body: Column(
          children: [
            // ── Messages ──────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(
                      color: Color(0xFF2A5298), strokeWidth: 2.5))
                  : _messages.isEmpty
                      ? _EmptyConversation(name: widget.providerName)
                      : ListView.builder(
                          controller: _scrollCtrl,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final msg  = _messages[i];
                            final mine = _isMine(msg);

                            bool showDate = i == 0;
                            if (!showDate) {
                              try {
                                final prev = DateTime.parse(
                                    _messages[i-1]['created_at']).toLocal();
                                final curr = DateTime.parse(
                                    msg['created_at']).toLocal();
                                showDate = prev.day != curr.day;
                              } catch (_) {}
                            }

                            return Column(
                              children: [
                                if (showDate)
                                  _DateSeparator(iso: msg['created_at']),
                                _MessageBubble(
                                  content: msg['content'] as String,
                                  isMine:  mine,
                                  time:    _formatTime(msg['created_at']),
                                  isRead:  msg['is_read'] == true,
                                ),
                              ],
                            );
                          },
                        ),
            ),

            // ── Input bar ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 12,
                    offset: const Offset(0, -3))],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _msgCtrl,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Color(0xFFADB5BD)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: _sending
                              ? const Color(0xFF2A5298).withOpacity(0.5)
                              : const Color(0xFF2A5298),
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyConversation extends StatelessWidget {
  final String name;
  const _EmptyConversation({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2A5298).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF2A5298), size: 38),
            ),
            const SizedBox(height: 16),
            Text('Start a conversation with $name',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w700, color: Color(0xFF1A3A6B))),
            const SizedBox(height: 6),
            Text('Send a message below to get started',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content, time;
  final bool isMine, isRead;

  const _MessageBubble({
    required this.content,
    required this.isMine,
    required this.time,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF2A5298) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(content,
                style: TextStyle(
                    fontSize: 14,
                    color: isMine ? Colors.white : const Color(0xFF1E293B),
                    height: 1.4)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time,
                    style: TextStyle(fontSize: 10,
                        color: isMine
                            ? Colors.white.withOpacity(0.65)
                            : Colors.grey.shade400)),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 13,
                    color: isRead
                        ? Colors.lightBlueAccent.withOpacity(0.9)
                        : Colors.white.withOpacity(0.65),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final String iso;
  const _DateSeparator({required this.iso});

  String _label() {
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day)
        return 'Today';
      final y = now.subtract(const Duration(days: 1));
      if (dt.year == y.year && dt.month == y.month && dt.day == y.day)
        return 'Yesterday';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade200)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(_label(),
                style: TextStyle(fontSize: 11,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Divider(color: Colors.grey.shade200)),
        ],
      ),
    );
  }
}