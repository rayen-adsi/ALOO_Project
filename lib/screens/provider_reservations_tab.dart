// lib/screens/provider_reservations_tab.dart
//
// Rules:
//  • When time is reached, client sees BOTH buttons: Complete+Review AND Report No-Show
//  • Once EITHER action is taken → the OTHER button disappears
//  • Report No-Show → opens a comment sheet (no stars, 1-star saved automatically),
//    marks reservation as 'reported', comment stored on provider's reviews page
//  • Complete+Review → normal star review sheet, marks as 'completed'

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/notification_provider.dart';
import '../services/api_services.dart';
import 'chat_screen.dart';
import 'agenda_screen.dart';

// ── Offer helpers ────────────────────────────────────────────────────────────

const String _offerPrefix = 'OFFER_JSON:';

Map<String, dynamic>? _parseOffer(String content) {
  if (!content.startsWith(_offerPrefix)) return null;
  try { return jsonDecode(content.substring(_offerPrefix.length)); }
  catch (_) { return null; }
}

String _encodeOffer(Map<String, dynamic> offer) =>
    '$_offerPrefix${jsonEncode(offer)}';

// ── Reservation model ────────────────────────────────────────────────────────

class _Reservation {
  final String description;
  final String date;
  final String time;
  final String address;
  String status;        // accepted | completed | reported
  bool   hasReview;     // completed flow done
  bool   hasReport;     // no-show flow done
  final String partnerName;
  final int    partnerId;
  final String partnerRole;
  final int    clientId;
  final int    providerId;

  _Reservation({
    required this.description, required this.date,
    required this.time,        required this.address,
    required this.status,      required this.hasReview,
    required this.hasReport,   required this.partnerName,
    required this.partnerId,   required this.partnerRole,
    required this.clientId,    required this.providerId,
  });

  String get reservationKey => '${clientId}_${providerId}_${date}_$time';

  DateTime get dateTime {
    try {
      final parts = date.split('/');
      if (parts.length == 3) {
        final d = DateTime(int.parse(parts[2]), int.parse(parts[1]),
            int.parse(parts[0]));
        if (time.isNotEmpty && time.contains(':')) {
          final tp = time.split(':');
          return DateTime(d.year, d.month, d.day,
              int.parse(tp[0]), int.parse(tp[1]));
        }
        return d;
      }
    } catch (_) {}
    return DateTime(2099);
  }

  bool get isTodayOrPast {
    final now = DateTime.now();
    final rd  = dateTime;
    return now.year  >= rd.year  &&
           now.month >= rd.month &&
           now.day   >= rd.day;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReservationsTab
// ─────────────────────────────────────────────────────────────────────────────

class ReservationsTab extends StatefulWidget {
  final int    userId;
  final String userRole;
  const ReservationsTab({super.key, required this.userId, required this.userRole});

  @override
  State<ReservationsTab> createState() => ReservationsTabState();
}

class ReservationsTabState extends State<ReservationsTab>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  List<_Reservation> _reservations = [];
  bool    _loading = true;
  String? _error;
  String  _filter  = 'all';

  @override
  void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(ReservationsTab old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId && widget.userId > 0) _load();
  }

  void reload() => _load();

  // ── Load ──────────────────────────────────────────────────────────────────
  // Shows:
  //   • ALL accepted reservations (need action)
  //   • completed/reported ONLY if within last 14 days (recent context)
  //   • Anything older and already done → visible only in Agenda

  Future<void> _load() async {
    if (widget.userId == 0) { setState(() => _loading = false); return; }
    setState(() { _loading = true; _error = null; });

    final cutoff = DateTime.now().subtract(const Duration(days: 14));

    try {
      final conversations = await ApiService.getConversations(
          userId: widget.userId, userType: widget.userRole);
      final List<_Reservation> all = [];

      for (final conv in conversations) {
        final bool   isClient    = widget.userRole == 'client';
        final int    partnerId   = isClient
            ? (conv['provider_id'] as int? ?? 0)
            : (conv['client_id']   as int? ?? 0);
        final String partnerName = isClient
            ? (conv['provider_name'] ?? '')
            : (conv['client_name']   ?? '');
        if (partnerId == 0) continue;

        final int clientId   = isClient ? widget.userId : partnerId;
        final int providerId = isClient ? partnerId : widget.userId;

        final messages = await ApiService.getConversation(
            clientId: clientId, providerId: providerId);

        final Map<String, Map<String, dynamic>> latest = {};
        for (final msg in messages) {
          final offer = _parseOffer(msg['content'] as String? ?? '');
          if (offer == null) continue;
          final key =
              '${offer['description']}|${offer['date']}|${offer['time']}';
          latest[key] = offer;
        }

        for (final offer in latest.values) {
          final status = offer['status'] as String? ?? 'pending';
          if (status != 'accepted' && status != 'completed' &&
              status != 'reported') continue;

          final res = _Reservation(
            description: offer['description'] ?? '',
            date:        offer['date']        ?? '',
            time:        offer['time']        ?? '',
            address:     offer['address']     ?? '',
            status:      status,
            hasReview:   status == 'completed',
            hasReport:   status == 'reported',
            partnerName: partnerName,
            partnerId:   partnerId,
            partnerRole: isClient ? 'provider' : 'client',
            clientId:    clientId,
            providerId:  providerId,
          );

          // Always include accepted; include done ones only if recent
          if (status == 'accepted' || res.dateTime.isAfter(cutoff)) {
            all.add(res);
          }
        }
      }

      // Sort: accepted first (soonest first), then recent done (newest first)
      all.sort((a, b) {
        final aActive = a.status == 'accepted';
        final bActive = b.status == 'accepted';
        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;
        if (aActive) return a.dateTime.compareTo(b.dateTime);
        return b.dateTime.compareTo(a.dateTime); // recent done: newest first
      });

      if (!mounted) return;
      setState(() { _reservations = all; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'error'; _loading = false; });
    }
  }

  List<_Reservation> get _filtered {
    switch (_filter) {
      case 'upcoming':
        return _reservations.where((r) => r.status == 'accepted').toList();
      case 'completed':
        return _reservations
            .where((r) => r.status == 'completed' || r.status == 'reported')
            .toList();
      default:
        return _reservations;
    }
  }

  void _openChat(_Reservation res) {
    final isClient = widget.userRole == 'client';
    Navigator.push(context, chatScreenRoute(
      providerId:   isClient ? res.partnerId : widget.userId,
      providerName: res.partnerName,
      clientId:     isClient ? null : res.partnerId,
      clientName:   isClient ? null : res.partnerName,
    )).then((_) => _load());
  }

  // ── Complete + Review ─────────────────────────────────────────────────────

  Future<void> _markCompleted(_Reservation res) async {
    final lang = context.read<LanguageProvider>();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(providerName: res.partnerName, lang: lang),
    );
    if (result == null || !mounted) return;

    try {
      await ApiService.addReview(
        providerId: res.providerId, clientId: res.clientId,
        rating:  (result['rating'] as num).toDouble(),
        comment: result['comment'] as String? ?? '',
      );
    } catch (_) {}

    try {
      await ApiService.sendMessage(
        senderId: widget.userId, senderType: widget.userRole,
        receiverId: res.providerId, receiverType: 'provider',
        content: _encodeOffer({
          'description': res.description, 'date': res.date,
          'time': res.time, 'address': res.address, 'status': 'completed',
        }),
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() { res.status = 'completed'; res.hasReview = true; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(lang.t('review_submitted')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF10B981)));
  }

  // ── Report No-Show ────────────────────────────────────────────────────────

  Future<void> _reportNoShow(_Reservation res) async {
    final lang = context.read<LanguageProvider>();

    // Open a comment sheet — no stars, just what happened
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _NoShowCommentSheet(providerName: res.partnerName, lang: lang),
    );
    if (result == null || !mounted) return;

    setState(() => res.hasReport = true); // optimistic

    try {
      final response = await ApiService.reportNoShow(
        clientId:       res.clientId,
        providerId:     res.providerId,
        reservationKey: res.reservationKey,
        description:    res.description,
        date:           res.date,
        time:           res.time,
        reason:         result['comment'] as String? ?? '',
      );

      if (!mounted) return;

      if (response['success'] == true) {
        // Send 'reported' status into the conversation so the reservation
        // tab shows the correct badge on next load
        try {
          await ApiService.sendMessage(
            senderId: widget.userId, senderType: widget.userRole,
            receiverId: res.providerId, receiverType: 'provider',
            content: _encodeOffer({
              'description': res.description, 'date': res.date,
              'time': res.time, 'address': res.address, 'status': 'reported',
            }),
          );
        } catch (_) {}

        setState(() { res.status = 'reported'; });
        context.read<NotificationProvider>().refresh();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.t('report_submitted')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444)));
      } else {
        setState(() => res.hasReport = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response['message'] as String? ?? lang.t('connection_error')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444)));
      }
    } catch (_) {
      if (mounted) setState(() => res.hasReport = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang     = context.watch<LanguageProvider>();
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(children: [
        Positioned.fill(
            child: Image.asset('assets/images/bg.png', fit: BoxFit.cover)),
        Positioned.fill(child: Container(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.05),
              Colors.white.withOpacity(0.75),
              Colors.white.withOpacity(0.97),
            ]),
        ))),
        SafeArea(child: Column(children: [

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8, offset: const Offset(0, 2))]),
                child: const Icon(Icons.calendar_today_rounded,
                    color: Color(0xFF2A5298), size: 18)),
              const SizedBox(width: 10),
              Text(lang.t('reservations'),
                style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900,
                  color: Color(0xFF1A3A6B), letterSpacing: -0.5)),
              const Spacer(),
              // Upcoming count badge
              if (_reservations.where((r) => r.status == 'accepted').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A5298).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '${_reservations.where((r) => r.status == 'accepted').length}',
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: Color(0xFF2A5298)))),
              const SizedBox(width: 8),
              // Agenda calendar button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AgendaScreen(
                    userId:   widget.userId,
                    userRole: widget.userRole,
                  )),
                ),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A6B),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF1A3A6B).withOpacity(0.30),
                      blurRadius: 8, offset: const Offset(0, 3))]),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: Colors.white, size: 18))),
            ])),
          const SizedBox(height: 16),

          // Filter chips
          if (_reservations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _FilterChip(
                  label:    lang.t('filter_all'),
                  isActive: _filter == 'all',
                  onTap:    () => setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                _FilterChip(
                  label:    lang.t('filter_upcoming'),
                  isActive: _filter == 'upcoming',
                  color:    const Color(0xFF2A5298),
                  onTap:    () => setState(() => _filter = 'upcoming')),
                const SizedBox(width: 8),
                _FilterChip(
                  label:    lang.t('filter_completed'),
                  isActive: _filter == 'completed',
                  color:    const Color(0xFF10B981),
                  onTap:    () => setState(() => _filter = 'completed')),
              ])),
          if (_reservations.isNotEmpty) const SizedBox(height: 12),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                    color: Color(0xFF2A5298), strokeWidth: 2.5))
                : _error != null
                    ? _ErrorState(onRetry: _load, lang: lang)
                    : _filtered.isEmpty
                        ? _EmptyState(lang: lang, hasFilter: _filter != 'all')
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: const Color(0xFF2A5298),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics()),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) {
                                final res = _filtered[i];
                                return _ReservationCard(
                                  reservation: res,
                                  lang:        lang,
                                  userRole:    widget.userRole,
                                  onChat:      () => _openChat(res),
                                  onComplete:  () => _markCompleted(res),
                                  onReport:    () => _reportNoShow(res),
                                );
                              },
                            ),
                          ),
          ),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESERVATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ReservationCard extends StatelessWidget {
  final _Reservation     reservation;
  final LanguageProvider lang;
  final String           userRole;
  final VoidCallback     onChat;
  final VoidCallback     onComplete;
  final VoidCallback     onReport;

  const _ReservationCard({
    required this.reservation, required this.lang, required this.userRole,
    required this.onChat, required this.onComplete, required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final isClient    = userRole == 'client';
    final timeReached = reservation.isTodayOrPast;
    final hasReview   = reservation.hasReview;
    final hasReport   = reservation.hasReport;

    // Status badge
    final Color    statusColor;
    final IconData statusIcon;
    final String   statusLabel;

    if (reservation.status == 'reported') {
      statusColor = const Color(0xFFEF4444);
      statusIcon  = Icons.flag_rounded;
      statusLabel = lang.t('status_reported');
    } else if (reservation.status == 'completed') {
      statusColor = const Color(0xFF10B981);
      statusIcon  = Icons.check_circle_rounded;
      statusLabel = lang.t('status_completed');
    } else if (timeReached) {
      statusColor = const Color(0xFFF59E0B);
      statusIcon  = Icons.hourglass_top_rounded;
      statusLabel = lang.t('status_ready');
    } else {
      statusColor = const Color(0xFF2A5298);
      statusIcon  = Icons.schedule_rounded;
      statusLabel = lang.t('status_upcoming');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        border: (isClient && timeReached && !hasReview && !hasReport)
            ? Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.4), width: 1.5)
            : null,
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 14, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header strip
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17))),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.handshake_rounded,
                  color: statusColor, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reservation.description,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: Color(0xFF1A3A6B))),
                const SizedBox(height: 2),
                Text(
                  '${isClient ? lang.t("provider") : lang.t("client")}: ${reservation.partnerName}',
                  style: TextStyle(fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
              ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(statusIcon, color: statusColor, size: 13),
                const SizedBox(width: 4),
                Text(statusLabel,
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: statusColor)),
              ])),
          ])),

        // Details
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(children: [
            if (reservation.date.isNotEmpty || reservation.time.isNotEmpty)
              _DetailRow(
                icon:  Icons.calendar_today_rounded,
                color: const Color(0xFF2A5298),
                text:  [reservation.date, reservation.time]
                    .where((s) => s.isNotEmpty)
                    .join(' ${lang.t("at")} ')),
            if (reservation.date.isNotEmpty || reservation.time.isNotEmpty)
              const SizedBox(height: 8),
            if (reservation.address.isNotEmpty)
              _DetailRow(
                icon:  Icons.location_on_rounded,
                color: const Color(0xFFEF4444),
                text:  reservation.address),
          ])),

        // Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: _buildActions(
            isClient:    isClient,
            timeReached: timeReached,
            hasReview:   hasReview,
            hasReport:   hasReport,
          )),
      ]),
    );
  }

  Widget _buildActions({
    required bool isClient,
    required bool timeReached,
    required bool hasReview,
    required bool hasReport,
  }) {
    // Provider view — chat only
    if (!isClient) {
      return _ActionBtn(
        label: lang.t('contact'), icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF2A5298), outlined: false, onTap: onChat);
    }

    // Client — time NOT reached yet
    if (!timeReached) {
      return _ActionBtn(
        label: lang.t('contact'), icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF2A5298), outlined: false, onTap: onChat);
    }

    // ── Client — time reached ─────────────────────────────────────
    // MUTUAL EXCLUSION:
    //   • If reviewed  → only show "Reviewed" badge + chat (hide report btn)
    //   • If reported  → only show "Reported" badge + chat (hide review btn)
    //   • If neither   → show BOTH action buttons + chat

    if (hasReview) {
      // Completed & reviewed — hide report button entirely
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _StatusBadge(
          icon:  Icons.star_rounded,
          label: lang.t('reviewed'),
          color: const Color(0xFF10B981)),
        const SizedBox(height: 8),
        _ActionBtn(
          label: lang.t('contact'), icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF2A5298), outlined: true, onTap: onChat),
      ]);
    }

    if (hasReport) {
      // Reported as no-show — hide complete button entirely
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _StatusBadge(
          icon:  Icons.flag_rounded,
          label: lang.t('already_reported'),
          color: const Color(0xFFEF4444)),
        const SizedBox(height: 8),
        _ActionBtn(
          label: lang.t('contact'), icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF2A5298), outlined: true, onTap: onChat),
      ]);
    }

    // Neither done yet — show both
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: _ActionBtn(
          label:    lang.t('mark_completed'),
          icon:     Icons.check_circle_rounded,
          color:    const Color(0xFF10B981),
          outlined: false,
          onTap:    onComplete)),
        const SizedBox(width: 8),
        Expanded(child: _ActionBtn(
          label:    lang.t('report_no_show'),
          icon:     Icons.flag_rounded,
          color:    const Color(0xFFEF4444),
          outlined: true,
          onTap:    onReport)),
      ]),
      const SizedBox(height: 8),
      _ActionBtn(
        label: lang.t('contact'), icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF2A5298), outlined: true, onTap: onChat),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _StatusBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    decoration: BoxDecoration(
      color:        color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.25))),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 6),
      Text(label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: color)),
    ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// NO-SHOW COMMENT SHEET
// Comment-only sheet (no stars) — 1-star is saved automatically on the backend
// ─────────────────────────────────────────────────────────────────────────────

class _NoShowCommentSheet extends StatefulWidget {
  final String providerName; final LanguageProvider lang;
  const _NoShowCommentSheet({required this.providerName, required this.lang});
  @override State<_NoShowCommentSheet> createState() => _NoShowCommentSheetState();
}

class _NoShowCommentSheetState extends State<_NoShowCommentSheet> {
  final _ctrl = TextEditingController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 20),

          // Icon + title
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.10),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.flag_rounded,
                  color: Color(0xFFEF4444), size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.t('report_no_show'),
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: Color(0xFF1A3A6B))),
                Text(widget.providerName,
                  style: TextStyle(fontSize: 13,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
              ])),
          ]),
          const SizedBox(height: 12),

          // Penalty info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.2))),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFFEF4444), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(lang.t('report_confirm_body'),
                style: TextStyle(fontSize: 12.5,
                    color: Colors.grey.shade700, height: 1.4))),
            ])),
          const SizedBox(height: 16),

          // Comment field
          TextField(
            controller: _ctrl,
            maxLines:   4,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText:  lang.t('report_reason_hint'),
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled:    true, fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFEF4444), width: 1.5)),
              contentPadding: const EdgeInsets.all(14))),
          const SizedBox(height: 20),

          // Buttons
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, null),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13)),
              child: Text(lang.t('cancel'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600)))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'comment': _ctrl.text.trim(),
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444), elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13)),
              child: Text(lang.t('report_no_show'),
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w700, color: Colors.white)))),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAR REVIEW SHEET (for Complete flow)
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  final String providerName; final LanguageProvider lang;
  const _ReviewSheet({required this.providerName, required this.lang});
  @override State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int    _rating = 0;
  final  _ctrl   = TextEditingController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  String _ratingLabel() {
    switch (_rating) {
      case 1: return widget.lang.t('rating_1');
      case 2: return widget.lang.t('rating_2');
      case 3: return widget.lang.t('rating_3');
      case 4: return widget.lang.t('rating_4');
      case 5: return widget.lang.t('rating_5');
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.star_rounded,
                  color: Color(0xFFFBBF24), size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.t('rate_provider'),
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: Color(0xFF1A3A6B))),
                Text(widget.providerName,
                  style: TextStyle(fontSize: 13,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
              ])),
          ]),
          const SizedBox(height: 24),
          Text(lang.t('how_was_service'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: Color(0xFF475569))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    star <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: star <= _rating
                        ? const Color(0xFFFBBF24)
                        : Colors.grey.shade300,
                    size: 40)));
            }),
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 8),
            Text(_ratingLabel(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                color: _rating >= 4
                    ? const Color(0xFF10B981)
                    : _rating >= 3
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444))),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl, maxLines: 3,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText:  lang.t('review_comment_hint'),
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true, fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF2A5298), width: 1.5)),
              contentPadding: const EdgeInsets.all(14))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _rating > 0
                    ? const Color(0xFF10B981)
                    : Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              label: Text(lang.t('submit_review'),
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w700, color: Colors.white)),
              onPressed: _rating > 0
                  ? () => Navigator.pop(context, {
                      'rating':  _rating,
                      'comment': _ctrl.text.trim(),
                    })
                  : null)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBtn extends StatefulWidget {
  final String label; final IconData icon; final Color color;
  final bool outlined; final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon,
      required this.color, required this.outlined, required this.onTap});
  @override State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => setState(() => _pressed = true),
    onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
    onTapCancel: ()  => setState(() => _pressed = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 38,
      decoration: BoxDecoration(
        color: widget.outlined
            ? (_pressed ? widget.color.withOpacity(0.08) : Colors.transparent)
            : (_pressed ? widget.color.withOpacity(0.85) : widget.color),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.color, width: 1.5)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(widget.icon, size: 14,
            color: widget.outlined ? widget.color : Colors.white),
        const SizedBox(width: 6),
        Text(widget.label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
              color: widget.outlined ? widget.color : Colors.white)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL ROW
// ─────────────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon; final Color color; final String text;
  const _DetailRow({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 15)),
    const SizedBox(width: 10),
    Expanded(child: Text(text,
      style: const TextStyle(fontSize: 13.5,
          fontWeight: FontWeight.w500, color: Color(0xFF475569)))),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label; final bool isActive;
  final Color color; final VoidCallback onTap;
  const _FilterChip({required this.label, required this.isActive,
      this.color = const Color(0xFF64748B), required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? color : Colors.grey.shade200,
          width: isActive ? 1.5 : 1),
        boxShadow: isActive ? [] : [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6, offset: const Offset(0, 2))]),
      child: Text(label,
        style: TextStyle(fontSize: 12.5,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: isActive ? color : Colors.grey.shade600)),
    ));
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY & ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final LanguageProvider lang; final bool hasFilter;
  const _EmptyState({required this.lang, this.hasFilter = false});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          color: Colors.white, shape: BoxShape.circle,
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16, offset: const Offset(0, 4))]),
        child: const Icon(Icons.event_note_rounded,
            size: 42, color: Color(0xFF2A5298))),
      const SizedBox(height: 20),
      Text(hasFilter ? lang.t('no_results') : lang.t('no_reservations'),
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B))),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50),
        child: Text(
          hasFilter ? lang.t('no_results_sub') : lang.t('no_reservations_sub'),
          style: TextStyle(fontSize: 13.5, color: Colors.grey.shade500),
          textAlign: TextAlign.center)),
    ]));
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry; final LanguageProvider lang;
  const _ErrorState({required this.onRetry, required this.lang});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.wifi_off_rounded, color: Colors.grey.shade400, size: 48),
      const SizedBox(height: 12),
      Text('Could not load',
          style: TextStyle(color: Colors.grey.shade500)),
      const SizedBox(height: 16),
      TextButton(
        onPressed: onRetry,
        child: Text(lang.t('retry'),
          style: const TextStyle(color: Color(0xFF2A5298),
              fontWeight: FontWeight.w700))),
    ]));
}