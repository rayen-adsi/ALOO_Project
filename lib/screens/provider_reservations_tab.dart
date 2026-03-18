// lib/screens/reservations_tab.dart
// Shared reservations tab — works for both providers and clients.
// Scans all conversations for accepted OFFER_JSON messages.
// Client can mark as completed + leave review when reservation time arrives.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import 'chat_screen.dart';

// ── Offer parsing ────────────────────────────────────────────────────────
const String _offerPrefix = 'OFFER_JSON:';

bool _isOfferMessage(String content) => content.startsWith(_offerPrefix);

Map<String, dynamic>? _parseOffer(String content) {
  if (!_isOfferMessage(content)) return null;
  try { return jsonDecode(content.substring(_offerPrefix.length)); }
  catch (_) { return null; }
}

String _encodeOffer(Map<String, dynamic> offer) =>
    '$_offerPrefix${jsonEncode(offer)}';

// ── Reservation model ────────────────────────────────────────────────────
class _Reservation {
  final String description;
  final String date;
  final String time;
  final String address;
  String status;        // accepted, completed
  final String partnerName;
  final int    partnerId;
  final String partnerRole;
  final int    clientId;
  final int    providerId;

  _Reservation({
    required this.description,
    required this.date,
    required this.time,
    required this.address,
    required this.status,
    required this.partnerName,
    required this.partnerId,
    required this.partnerRole,
    required this.clientId,
    required this.providerId,
  });

  String get key => '$description|$date|$time';

  /// Parse date string (dd/MM/yyyy) to DateTime
  DateTime get dateTime {
    try {
      final parts = date.split('/');
      if (parts.length == 3) {
        final d = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        // Add time if available
        if (time.isNotEmpty && time.contains(':')) {
          final tp = time.split(':');
          return DateTime(d.year, d.month, d.day, int.parse(tp[0]), int.parse(tp[1]));
        }
        return d;
      }
    } catch (_) {}
    return DateTime(2099);
  }

  /// True if the reservation date/time has passed
  bool get isTimeReached => DateTime.now().isAfter(dateTime);

  /// True if reservation date is today or has passed
  bool get isTodayOrPast {
    final now = DateTime.now();
    final rd  = dateTime;
    return now.year >= rd.year && now.month >= rd.month && now.day >= rd.day;
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
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ReservationsTab old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId && widget.userId > 0) _load();
  }

  void reload() => _load();

  Future<void> _load() async {
    if (widget.userId == 0) { setState(() => _loading = false); return; }
    setState(() { _loading = true; _error = null; });

    try {
      final conversations = await ApiService.getConversations(
        userId: widget.userId, userType: widget.userRole);

      final List<_Reservation> allReservations = [];

      for (final conv in conversations) {
        final bool isClient = widget.userRole == 'client';
        final int partnerId = isClient
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

        // Track latest status per offer
        final Map<String, Map<String, dynamic>> latestOffers = {};
        for (final msg in messages) {
          final content = msg['content'] as String? ?? '';
          final offer = _parseOffer(content);
          if (offer == null) continue;
          final key = '${offer['description']}|${offer['date']}|${offer['time']}';
          latestOffers[key] = offer;
        }

        for (final entry in latestOffers.entries) {
          final offer  = entry.value;
          final status = offer['status'] as String? ?? 'pending';

          if (status == 'accepted' || status == 'completed') {
            allReservations.add(_Reservation(
              description: offer['description'] ?? '',
              date:        offer['date']        ?? '',
              time:        offer['time']        ?? '',
              address:     offer['address']     ?? '',
              status:      status,
              partnerName: partnerName,
              partnerId:   partnerId,
              partnerRole: isClient ? 'provider' : 'client',
              clientId:    clientId,
              providerId:  providerId,
            ));
          }
        }
      }

      // Sort: upcoming first, then completed
      allReservations.sort((a, b) {
        if (a.status == 'accepted' && b.status == 'completed') return -1;
        if (a.status == 'completed' && b.status == 'accepted') return 1;
        return a.dateTime.compareTo(b.dateTime);
      });

      if (!mounted) return;
      setState(() { _reservations = allReservations; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'error'; _loading = false; });
    }
  }

  List<_Reservation> get _filtered {
    if (_filter == 'upcoming')  return _reservations.where((r) => r.status == 'accepted').toList();
    if (_filter == 'completed') return _reservations.where((r) => r.status == 'completed').toList();
    return _reservations;
  }

  void _openChat(_Reservation res) {
    final isClient = widget.userRole == 'client';
    Navigator.push(context, chatScreenRoute(
      providerId:   isClient ? res.partnerId : widget.userId,
      providerName: isClient ? res.partnerName : res.partnerName,
      clientId:     isClient ? null : res.partnerId,
      clientName:   isClient ? null : res.partnerName,
    )).then((_) => _load());
  }

  /// Mark reservation as completed + show review dialog
  Future<void> _markCompleted(_Reservation res) async {
    final lang = context.read<LanguageProvider>();

    // Show review bottom sheet
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        providerName: res.partnerName,
        lang:         lang,
      ),
    );

    if (result == null || !mounted) return;

    // 1. Submit review to backend
    try {
      await ApiService.addReview(
        providerId: res.providerId,
        clientId:   res.clientId,
        rating:     (result['rating'] as num).toDouble(),
        comment:    result['comment'] as String? ?? '',
      );
    } catch (_) {}

    // 2. Send completed status as message
    try {
      final completedOffer = {
        'description': res.description,
        'date':        res.date,
        'time':        res.time,
        'address':     res.address,
        'status':      'completed',
      };
      await ApiService.sendMessage(
        senderId:     widget.userId,
        senderType:   widget.userRole,
        receiverId:   res.providerId,
        receiverType: 'provider',
        content:      _encodeOffer(completedOffer),
      );
    } catch (_) {}

    // 3. Update local state
    if (mounted) {
      setState(() => res.status = 'completed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.t('review_submitted')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang     = context.watch<LanguageProvider>();
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/bg.png', fit: BoxFit.cover)),
          Positioned.fill(child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.75), Colors.white.withOpacity(0.97)],
            )),
          )),

          SafeArea(
            child: Column(children: [
              // ── Header ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]),
                    child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF2A5298), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(lang.t('reservations'),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1A3A6B), letterSpacing: -0.5)),
                  const Spacer(),
                  if (_reservations.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A5298).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12)),
                      child: Text('${_reservations.length}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF2A5298))),
                    ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Filter chips ────────────────────────────────
              if (_reservations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    _FilterChip(label: lang.t('filter_all'),       isActive: _filter == 'all',       onTap: () => setState(() => _filter = 'all')),
                    const SizedBox(width: 8),
                    _FilterChip(label: lang.t('filter_upcoming'),  isActive: _filter == 'upcoming',  color: const Color(0xFF2A5298), onTap: () => setState(() => _filter = 'upcoming')),
                    const SizedBox(width: 8),
                    _FilterChip(label: lang.t('filter_completed'), isActive: _filter == 'completed', color: const Color(0xFF10B981), onTap: () => setState(() => _filter = 'completed')),
                  ]),
                ),
              if (_reservations.isNotEmpty) const SizedBox(height: 12),

              // ── List ────────────────────────────────────────
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2A5298), strokeWidth: 2.5))
                    : _error != null
                        ? _ErrorState(onRetry: _load, lang: lang)
                        : filtered.isEmpty
                            ? _EmptyState(lang: lang, hasFilter: _filter != 'all')
                            : RefreshIndicator(
                                onRefresh: _load, color: const Color(0xFF2A5298),
                                child: ListView.builder(
                                  physics:   const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  padding:   const EdgeInsets.fromLTRB(16, 4, 16, 20),
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) => _ReservationCard(
                                    reservation:   filtered[i],
                                    lang:          lang,
                                    userRole:      widget.userRole,
                                    onChat:        () => _openChat(filtered[i]),
                                    onComplete:    () => _markCompleted(filtered[i]),
                                  ),
                                ),
                              ),
              ),
            ]),
          ),
        ],
      ),
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

  const _ReservationCard({
    required this.reservation,
    required this.lang,
    required this.userRole,
    required this.onChat,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted  = reservation.status == 'completed';
    final canComplete  = userRole == 'client' && !isCompleted && reservation.isTodayOrPast;

    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    if (isCompleted) {
      statusColor = const Color(0xFF10B981);
      statusIcon  = Icons.check_circle_rounded;
      statusLabel = lang.t('status_completed');
    } else if (reservation.isTodayOrPast) {
      statusColor = const Color(0xFFF59E0B);
      statusIcon  = Icons.hourglass_top_rounded;
      statusLabel = lang.t('status_ready');
    } else {
      statusColor = const Color(0xFF2A5298);
      statusIcon  = Icons.schedule_rounded;
      statusLabel = lang.t('status_upcoming');
    }

    final partnerLabel = userRole == 'client'
        ? lang.t('provider') : lang.t('client');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: canComplete ? Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4), width: 1.5) : null,
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17))),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.handshake_rounded, color: statusColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reservation.description,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B))),
                  const SizedBox(height: 2),
                  Text('$partnerLabel: ${reservation.partnerName}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, color: statusColor, size: 13),
                  const SizedBox(width: 4),
                  Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ]),
              ),
            ]),
          ),

          // ── Details ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(children: [
              if (reservation.date.isNotEmpty || reservation.time.isNotEmpty)
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  color: const Color(0xFF2A5298),
                  text: [reservation.date, reservation.time]
                      .where((s) => s.isNotEmpty).join(' ${lang.t("at")} '),
                ),
              if (reservation.date.isNotEmpty || reservation.time.isNotEmpty)
                const SizedBox(height: 8),
              if (reservation.address.isNotEmpty)
                _DetailRow(
                  icon: Icons.location_on_rounded,
                  color: const Color(0xFFEF4444),
                  text: reservation.address,
                ),
            ]),
          ),

          // ── Actions ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(children: [
              // Chat button
              Expanded(
                child: _ActionBtn(
                  label:    lang.t('contact'),
                  icon:     Icons.chat_bubble_rounded,
                  color:    const Color(0xFF2A5298),
                  outlined: canComplete, // outline style if complete button is shown
                  onTap:    onChat,
                ),
              ),

              // ✅ Complete + Review button (client only, time reached, not completed)
              if (canComplete) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    label:    lang.t('mark_completed'),
                    icon:     Icons.check_circle_rounded,
                    color:    const Color(0xFF10B981),
                    outlined: false,
                    onTap:    onComplete,
                  ),
                ),
              ],

              // Completed badge
              if (isCompleted) ...[
                const SizedBox(width: 10),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.star_rounded, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 4),
                    Text(lang.t('reviewed'), style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                  ]),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.outlined, required this.onTap});
  @override State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
          border: Border.all(color: widget.color, width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(widget.icon, size: 14,
            color: widget.outlined ? widget.color : Colors.white),
          const SizedBox(width: 6),
          Text(widget.label, style: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w700,
            color: widget.outlined ? widget.color : Colors.white)),
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon; final Color color; final String text;
  const _DetailRow({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 30, height: 30,
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 15)),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFF475569)))),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// REVIEW BOTTOM SHEET — star rating + comment
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  final String           providerName;
  final LanguageProvider lang;
  const _ReviewSheet({required this.providerName, required this.lang});
  @override State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int    _rating  = 0;
  final  _commentCtrl = TextEditingController();

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 20),

            // Title
            Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.t('rate_provider'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B))),
                  Text(widget.providerName,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                ],
              )),
            ]),
            const SizedBox(height: 24),

            // Star rating
            Text(lang.t('how_was_service'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starIndex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      starIndex <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: starIndex <= _rating
                          ? const Color(0xFFFBBF24)
                          : Colors.grey.shade300,
                      size: 40,
                    ),
                  ),
                );
              }),
            ),

            // Rating label
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Text(
                _ratingLabel(lang),
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: _rating >= 4 ? const Color(0xFF10B981)
                       : _rating >= 3 ? const Color(0xFFF59E0B)
                       : const Color(0xFFEF4444)),
              ),
            ],

            const SizedBox(height: 20),

            // Comment
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: lang.t('review_comment_hint'),
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                filled: true, fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2A5298), width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _rating > 0
                      ? const Color(0xFF10B981)
                      : Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                label: Text(lang.t('submit_review'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                onPressed: _rating > 0 ? () {
                  Navigator.pop(context, {
                    'rating':  _rating,
                    'comment': _commentCtrl.text.trim(),
                  });
                } : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(LanguageProvider lang) {
    switch (_rating) {
      case 1: return lang.t('rating_1');
      case 2: return lang.t('rating_2');
      case 3: return lang.t('rating_3');
      case 4: return lang.t('rating_4');
      case 5: return lang.t('rating_5');
      default: return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label; final bool isActive; final Color color; final VoidCallback onTap;
  const _FilterChip({required this.label, required this.isActive, this.color = const Color(0xFF64748B), required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? color : Colors.grey.shade200, width: isActive ? 1.5 : 1),
        boxShadow: isActive ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12.5, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        color: isActive ? color : Colors.grey.shade600)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY & ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final LanguageProvider lang; final bool hasFilter;
  const _EmptyState({required this.lang, this.hasFilter = false});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 90, height: 90,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))]),
      child: const Icon(Icons.event_note_rounded, size: 42, color: Color(0xFF2A5298))),
    const SizedBox(height: 20),
    Text(hasFilter ? lang.t('no_results') : lang.t('no_reservations'),
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
    const SizedBox(height: 8),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Text(hasFilter ? lang.t('no_results_sub') : lang.t('no_reservations_sub'),
        style: TextStyle(fontSize: 13.5, color: Colors.grey.shade500), textAlign: TextAlign.center)),
  ]));
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry; final LanguageProvider lang;
  const _ErrorState({required this.onRetry, required this.lang});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.wifi_off_rounded, color: Colors.grey.shade400, size: 48),
    const SizedBox(height: 12),
    Text('Could not load', style: TextStyle(color: Colors.grey.shade500)),
    const SizedBox(height: 16),
    TextButton(onPressed: onRetry,
      child: Text(lang.t('retry'), style: const TextStyle(color: Color(0xFF2A5298), fontWeight: FontWeight.w700))),
  ]));
}