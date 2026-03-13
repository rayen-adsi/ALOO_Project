// lib/screens/conversations_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../services/api_services.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final int    userId;
  final String userRole;

  const ConversationsScreen({
    super.key,
    this.userId   = 0,
    this.userRole = 'client',
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.userId > 0) _load();
    else setState(() => _loading = false);
  }

  @override
  void didUpdateWidget(ConversationsScreen old) {
    super.didUpdateWidget(old);
    if (old.userId == 0 && widget.userId > 0) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getConversations(
        userId:   widget.userId,
        userType: widget.userRole,
      );
      if (!mounted) return;
      setState(() { _conversations = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Could not load conversations'; _loading = false; });
    }
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/bg.png', fit: BoxFit.cover)),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.80),
                      Colors.white.withOpacity(0.97),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 4, height: 26,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF1A3A6B), Color(0xFF2A5298)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Messages',
                          style: TextStyle(fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A3A6B))),
                        const Spacer(),
                        if (_conversations.isNotEmpty)
                          GestureDetector(
                            onTap: _load,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A5298).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.refresh_rounded,
                                  color: Color(0xFF2A5298), size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Content ─────────────────────────────────────
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(
                            color: Color(0xFF2A5298), strokeWidth: 2.5))
                        : _error != null
                            ? Center(child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.wifi_off_rounded,
                                      color: Colors.grey.shade400, size: 48),
                                  const SizedBox(height: 12),
                                  Text(_error!,
                                      style: TextStyle(color: Colors.grey.shade500)),
                                  const SizedBox(height: 12),
                                  TextButton(onPressed: _load,
                                      child: const Text('Retry')),
                                ],
                              ))
                            : _conversations.isEmpty
                                ? _EmptyState()
                                : RefreshIndicator(
                                    onRefresh: _load,
                                    color: const Color(0xFF2A5298),
                                    child: ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                      itemCount: _conversations.length,
                                      itemBuilder: (_, i) {
                                        final c = _conversations[i];
                                        final isClient = widget.userRole == 'client';
                                        final name = isClient
                                            ? c['provider_name'] ?? ''
                                            : c['client_name']   ?? '';
                                        final category = isClient
                                            ? c['category'] ?? ''
                                            : '';
                                        final providerId = isClient
                                            ? c['provider_id'] as int
                                            : widget.userId;
                                        final unread = (c['unread_count'] ?? 0) as int;

                                        return _ConversationTile(
                                          name:         name,
                                          category:     category,
                                          lastMessage:  c['last_message'] ?? '',
                                          time:         _formatTime(
                                              c['last_message_time'] ?? ''),
                                          unreadCount:  unread,
                                          onTap: () async {
                                            await Navigator.push(context,
                                              MaterialPageRoute(builder: (_) =>
                                                ChatScreen(
                                                  providerId:       providerId,
                                                  providerName:     name,
                                                  providerCategory: category,
                                                )));
                                            _load(); // refresh unread count after returning
                                          },
                                        );
                                      },
                                    ),
                                  ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF2A5298).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: Color(0xFF2A5298), size: 42),
          ),
          const SizedBox(height: 16),
          const Text('No conversations yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: Color(0xFF1A3A6B))),
          const SizedBox(height: 6),
          Text('Contact a provider to start chatting',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final String   name, category, lastMessage, time;
  final int      unreadCount;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.category,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final hasUnread = widget.unreadCount > 0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 52, height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A3A6B), Color(0xFF2A5298)],
                  ),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasUnread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: const Color(0xFF0F172A))),
                    if (widget.category.isNotEmpty)
                      Text(widget.category,
                          style: const TextStyle(fontSize: 11,
                              color: Color(0xFF2A5298),
                              fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      widget.lastMessage.isEmpty
                          ? 'No messages yet'
                          : widget.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: hasUnread
                              ? const Color(0xFF1A3A6B)
                              : Colors.grey.shade500,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.w400),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Time + unread badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(widget.time,
                      style: TextStyle(
                          fontSize: 11,
                          color: hasUnread
                              ? const Color(0xFF2A5298)
                              : Colors.grey.shade400,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A5298),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.unreadCount > 99
                            ? '99+'
                            : '${widget.unreadCount}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
