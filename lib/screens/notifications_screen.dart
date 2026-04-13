// lib/screens/notifications_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../core/notification_provider.dart';
import '../services/api_services.dart';
import 'chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool   _loading  = true;
  int    _userId   = 0;
  String _userType = 'client';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await UserSession.load();
    _userId   = session['id']   ?? 0;
    _userType = session['role'] ?? 'client';

    if (_userId == 0) { setState(() => _loading = false); return; }

    try {
      final data = await ApiService.getNotifications(
          userId: _userId, userType: _userType);
      if (!mounted) return;
      setState(() { _notifications = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ── Mark single read ──────────────────────────────────────────────────────

  Future<void> _markRead(int notifId, int index) async {
    if (_notifications[index]['is_read'] == true) return;
    setState(() => _notifications[index]['is_read'] = true);
    try {
      await ApiService.markNotificationRead(notifId);
      if (mounted) context.read<NotificationProvider>().refresh();
    } catch (_) {
      if (mounted) setState(() => _notifications[index]['is_read'] = false);
    }
  }

  // ── Mark all read ─────────────────────────────────────────────────────────

  Future<void> _markAllRead() async {
    final hasUnread = _notifications.any((n) => n['is_read'] == false);
    if (!hasUnread) return;
    setState(() { for (final n in _notifications) n['is_read'] = true; });
    try {
      await ApiService.markAllNotificationsRead(
          userId: _userId, userType: _userType);
      if (mounted) context.read<NotificationProvider>().clearBadge();
    } catch (_) {}
  }

  // ── Delete single ─────────────────────────────────────────────────────────

  Future<void> _deleteNotification(int index) async {
    final notif     = _notifications[index];
    final notifId   = notif['id']      as int? ?? 0;
    final wasUnread = notif['is_read'] == false;

    setState(() => _notifications.removeAt(index));

    try {
      await ApiService.deleteNotification(notifId);
      if (mounted && wasUnread) {
        context.read<NotificationProvider>().refresh();
      }
    } catch (_) {
      if (mounted) setState(() => _notifications.insert(index, notif));
    }
  }

  // ── Delete all ────────────────────────────────────────────────────────────

  Future<void> _deleteAll() async {
    final lang = context.read<LanguageProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text(lang.t('delete_all_confirm'),
          style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800,
            color: Color(0xFF1A3A6B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.t('cancel'),
              style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444), elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.t('delete_all_notifications'),
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final backup = List<Map<String, dynamic>>.from(_notifications);
    setState(() => _notifications.clear());

    try {
      await ApiService.deleteAllNotifications(
          userId: _userId, userType: _userType);
      if (mounted) context.read<NotificationProvider>().clearBadge();
    } catch (_) {
      if (mounted) setState(() => _notifications = backup);
    }
  }

  // ── Parse notification ────────────────────────────────────────────────────

  _ParsedNotif _parse(Map<String, dynamic> n) {
    final raw  = n['message'] as String? ?? '';
    final type = n['type']    as String? ?? '';
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return _ParsedNotif(
        text:         decoded['text']          as String? ?? raw,
        senderName:   decoded['sender_name']   as String? ?? '',
        senderId:     decoded['sender_id']     as int?    ?? 0,
        senderType:   decoded['sender_type']   as String? ?? '',
        receiverId:   decoded['receiver_id']   as int?    ?? 0,
        receiverType: decoded['receiver_type'] as String? ?? '',
        senderPhoto:  decoded['sender_photo']  as String?,
        senderAvatar: (decoded['sender_avatar'] as int?) ?? 0,
        rating:       (decoded['rating']        as num?)?.toDouble(),
        reminderKey:  decoded['reminder_key']  as String?,
        clientId:     decoded['client_id']     as int?,
        providerId:   decoded['provider_id']   as int?,
        partnerName:  decoded['partner_name']  as String?,
        type:         type,
      );
    } catch (_) {
      return _ParsedNotif(
        text: raw, senderName: '', senderId: 0, senderType: '',
        receiverId: 0, receiverType: '', senderPhoto: null,
        senderAvatar: 0, type: type,
      );
    }
  }

  // ── Tap handler ───────────────────────────────────────────────────────────

  void _onTap(int notifId, int index) {
    _markRead(notifId, index);
    final p = _parse(_notifications[index]);

    if (p.type == 'reminder') { _navigateFromReminder(p); return; }
    // System types — no navigation
    if (p.senderType == 'system' || p.senderId == 0) return;
    _navigateToChat(p);
  }

  void _navigateToChat(_ParsedNotif p) {
    if (p.senderId == 0 || p.senderType.isEmpty) return;

    final int    clientId,   providerId;
    final String providerName;
    final int?   clientIdArg;
    final String? clientNameArg;

    if (_userType == 'client') {
      clientId      = _userId;
      providerId    = p.senderId;
      providerName  = p.senderName;
      clientIdArg   = null;
      clientNameArg = null;
    } else {
      clientId      = p.senderId;
      providerId    = _userId;
      providerName  = p.senderName;
      clientIdArg   = p.senderId;
      clientNameArg = p.senderName;
    }

    Navigator.push(context, chatScreenRoute(
      providerId:   providerId,
      providerName: providerName,
      clientId:     clientIdArg,
      clientName:   clientNameArg,
    ));
  }

  void _navigateFromReminder(_ParsedNotif p) {
    final clientId    = p.clientId   ?? 0;
    final providerId  = p.providerId ?? 0;
    final partnerName = p.partnerName ?? '';
    if (clientId == 0 || providerId == 0) return;

    if (_userType == 'client') {
      Navigator.push(context, chatScreenRoute(
        providerId: providerId, providerName: partnerName));
    } else {
      Navigator.push(context, chatScreenRoute(
        providerId:   providerId,
        providerName: partnerName,
        clientId:     clientId,
        clientName:   partnerName));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int get _unreadCount =>
      _notifications.where((n) => n['is_read'] == false).length;

  String _formatTime(String? iso, LanguageProvider lang) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final diff = DateTime.now()
          .difference(DateTime.parse(iso).toLocal());
      if (diff.inMinutes < 1)  return lang.t('just_now');
      if (diff.inMinutes < 60) return '${diff.inMinutes} ${lang.t('minutes_ago')}';
      if (diff.inHours   < 24) return '${diff.inHours} ${lang.t('hours_ago')}';
      return '${diff.inDays} ${lang.t('days_ago')}';
    } catch (_) { return ''; }
  }

  _NotifStyle _styleFor(String type) {
    switch (type) {
      case 'new_message':
        return _NotifStyle(icon: Icons.chat_bubble_rounded,
            color: const Color(0xFF2A5298), bg: const Color(0xFFEFF6FF));
      case 'new_review':
        return _NotifStyle(icon: Icons.star_rounded,
            color: const Color(0xFFF59E0B), bg: const Color(0xFFFFFBEB));
      case 'reminder':
        return _NotifStyle(icon: Icons.alarm_rounded,
            color: const Color(0xFFEF4444), bg: const Color(0xFFFFF1F2));
      case 'milestone':
        return _NotifStyle(icon: Icons.emoji_events_rounded,
            color: const Color(0xFFF59E0B), bg: const Color(0xFFFFFBEB));
      case 'no_show_report':
        return _NotifStyle(icon: Icons.flag_rounded,
            color: const Color(0xFFEF4444), bg: const Color(0xFFFFF1F2));
      case 'profile_complete':
        return _NotifStyle(icon: Icons.verified_rounded,
            color: const Color(0xFF8B5CF6), bg: const Color(0xFFF5F3FF));
      // ── Offer types ──────────────────────────────────────────────
      case 'offer_received':
        return _NotifStyle(icon: Icons.handshake_rounded,
            color: const Color(0xFF2A5298), bg: const Color(0xFFEFF6FF));
      case 'offer_accepted':
        return _NotifStyle(icon: Icons.check_circle_rounded,
            color: const Color(0xFF10B981), bg: const Color(0xFFECFDF5));
      case 'offer_refused':
        return _NotifStyle(icon: Icons.cancel_rounded,
            color: const Color(0xFFEF4444), bg: const Color(0xFFFFF1F2));
      case 'job_completed':
        return _NotifStyle(icon: Icons.star_rounded,
            color: const Color(0xFF10B981), bg: const Color(0xFFECFDF5));
      default:
        return _NotifStyle(icon: Icons.notifications_rounded,
            color: const Color(0xFF8B5CF6), bg: const Color(0xFFF5F3FF));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Stack(children: [
          Positioned.fill(
              child: Image.asset('assets/images/bg.png', fit: BoxFit.cover)),
          Positioned.fill(child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.75),
                Colors.white.withOpacity(0.97),
              ],
            )),
          )),

          SafeArea(child: Column(children: [

            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF1A3A6B), size: 20)),
                Expanded(child: Text(lang.t('notifications_title'),
                  style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: Color(0xFF1A3A6B), letterSpacing: -0.5))),
                if (_unreadCount > 0)
                  TextButton(
                    onPressed: _markAllRead,
                    child: Text(lang.t('mark_all_read'),
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: Color(0xFF2A5298)))),
                if (_notifications.isNotEmpty)
                  IconButton(
                    onPressed: _deleteAll,
                    tooltip: lang.t('delete_all_notifications'),
                    icon: Icon(Icons.delete_sweep_rounded,
                        color: Colors.grey.shade400, size: 22)),
              ]),
            ),

            // ── Unread chip ───────────────────────────────────────
            if (_unreadCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A5298).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '$_unreadCount ${lang.t('notif_unread_count')}',
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: Color(0xFF2A5298)))))),

            const SizedBox(height: 8),

            // ── List ──────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(
                      color: Color(0xFF2A5298), strokeWidth: 2.5))
                  : _notifications.isEmpty
                      ? _EmptyState(lang: lang)
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: const Color(0xFF2A5298),
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                                16, 4, 16, 24),
                            itemCount: _notifications.length,
                            itemBuilder: (_, i) {
                              final n     = _notifications[i];
                              final id    = n['id']      as int? ?? 0;
                              final read  = n['is_read'] == true;
                              final time  = _formatTime(
                                  n['created_at'] as String?, lang);
                              final p     = _parse(n);
                              final style = _styleFor(p.type);

                              return Dismissible(
                                key: ValueKey('$id-$i'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(16)),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete_rounded,
                                      color: Colors.white, size: 26)),
                                confirmDismiss: (_) async => true,
                                onDismissed: (_) => _deleteNotification(i),
                                child: _NotifTile(
                                  parsed:   p,
                                  time:     time,
                                  isRead:   read,
                                  style:    style,
                                  lang:     lang,
                                  onTap:    () => _onTap(id, i),
                                  onDelete: () => _deleteNotification(i),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ])),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _ParsedNotif {
  final String  text;
  final String  senderName;
  final int     senderId;
  final String  senderType;
  final int     receiverId;
  final String  receiverType;
  final String? senderPhoto;
  final int     senderAvatar;
  final double? rating;
  final String? reminderKey;
  final int?    clientId;
  final int?    providerId;
  final String? partnerName;
  final String  type;

  const _ParsedNotif({
    required this.text,        required this.senderName,
    required this.senderId,    required this.senderType,
    required this.receiverId,  required this.receiverType,
    required this.senderPhoto, required this.senderAvatar,
    required this.type,
    this.rating, this.reminderKey, this.clientId,
    this.providerId, this.partnerName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// STYLE
// ─────────────────────────────────────────────────────────────────────────────

class _NotifStyle {
  final IconData icon; final Color color, bg;
  const _NotifStyle({
    required this.icon, required this.color, required this.bg});
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION TILE
// ─────────────────────────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final _ParsedNotif     parsed;
  final String           time;
  final bool             isRead;
  final _NotifStyle      style;
  final LanguageProvider lang;
  final VoidCallback     onTap;
  final VoidCallback     onDelete;

  const _NotifTile({
    required this.parsed,   required this.time,
    required this.isRead,   required this.style,
    required this.lang,     required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
          border: isRead
              ? Border.all(color: Colors.grey.shade100)
              : Border.all(
                  color: const Color(0xFF2A5298).withOpacity(0.18),
                  width: 1.2),
          boxShadow: [BoxShadow(
            color:      Colors.black.withOpacity(isRead ? 0.04 : 0.07),
            blurRadius: isRead ? 8 : 12,
            offset:     const Offset(0, 3))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Avatar
          _SenderAvatar(
            photo:       parsed.senderPhoto,
            avatarIndex: parsed.senderAvatar,
            name:        parsed.senderName,
            type:        parsed.type,
            style:       style),
          const SizedBox(width: 12),

          // Content
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (parsed.senderName.isNotEmpty &&
                  parsed.senderType != 'system') ...[
                Text(parsed.senderName,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: Color(0xFF2A5298))),
                const SizedBox(height: 2),
              ],
              Text(parsed.text,
                style: TextStyle(
                  fontSize:   14,
                  fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                  color: isRead
                      ? const Color(0xFF475569)
                      : const Color(0xFF0F172A),
                  height: 1.4)),
              const SizedBox(height: 5),
              Row(children: [
                _TypeBadge(type: parsed.type, style: style, lang: lang),
                const SizedBox(width: 8),
                Text(time,
                  style: TextStyle(fontSize: 11,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500)),
              ]),
            ])),

          // Right column: unread dot + delete
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isRead)
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 4, right: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A5298), shape: BoxShape.circle))
              else
                const SizedBox(width: 8, height: 8),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color:        Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.delete_outline_rounded,
                    color: Colors.grey.shade400, size: 16))),
            ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SENDER AVATAR
// ─────────────────────────────────────────────────────────────────────────────

class _SenderAvatar extends StatelessWidget {
  final String?     photo;
  final int         avatarIndex;
  final String      name;
  final String      type;
  final _NotifStyle style;

  const _SenderAvatar({
    required this.photo,       required this.avatarIndex,
    required this.name,        required this.type,
    required this.style,
  });

  bool get _isSystem =>
      type == 'milestone' || type == 'reminder' || type == 'profile_complete';

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: style.color.withOpacity(0.35), width: 2)),
        child: ClipOval(child: _buildInner())),
      Positioned(bottom: -2, right: -2,
        child: Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color:  style.color, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5)),
          child: Icon(style.icon, color: Colors.white, size: 10))),
    ]);
  }

  Widget _buildInner() {
    if (_isSystem) {
      return Container(color: style.bg,
        child: Center(
            child: Icon(style.icon, color: style.color, size: 24)));
    }
    if (photo != null && photo!.isNotEmpty) {
      return Image.network(photo!, width: 48, height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarOrInitial());
    }
    return _avatarOrInitial();
  }

  Widget _avatarOrInitial() {
    if (avatarIndex > 0) {
      final n = (avatarIndex.clamp(0, 14) + 1).toString().padLeft(2, '0');
      return Image.asset('assets/images/avatars/avatar_$n.png',
          width: 48, height: 48, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initial());
    }
    return _initial();
  }

  Widget _initial() => Container(
    color: style.color.withOpacity(0.15),
    child: Center(child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
          color: style.color))));
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String           type;
  final _NotifStyle      style;
  final LanguageProvider lang;

  const _TypeBadge({
    required this.type, required this.style, required this.lang});

  String get _label {
    switch (type) {
      case 'new_message':      return lang.t('notif_type_new_message');
      case 'new_review':       return lang.t('notif_type_new_review');
      case 'reminder':         return lang.t('notif_type_reminder');
      case 'milestone':        return lang.t('notif_type_milestone');
      case 'no_show_report':   return lang.t('notif_type_no_show_report');
      case 'profile_complete': return lang.t('notif_type_profile_complete');
      // ── Offer types ────────────────────────────────────────────
      case 'offer_received':   return lang.t('notif_type_offer_received');
      case 'offer_accepted':   return lang.t('notif_type_offer_accepted');
      case 'offer_refused':    return lang.t('notif_type_offer_refused');
      case 'job_completed':    return lang.t('notif_type_job_completed');
      default:                 return 'Update';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        style.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(style.icon, color: style.color, size: 10),
        const SizedBox(width: 3),
        Text(_label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: style.color)),
      ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final LanguageProvider lang;
  const _EmptyState({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: Colors.white, shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16, offset: const Offset(0, 4))]),
          child: const Icon(Icons.notifications_none_rounded,
              size: 44, color: Color(0xFF2A5298))),
        const SizedBox(height: 20),
        Text(lang.t('no_notifications'),
          style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50),
          child: Text(lang.t('no_notifications_sub'),
            style: TextStyle(
                fontSize: 13.5, color: Colors.grey.shade500),
            textAlign: TextAlign.center)),
      ]));
  }
}