// lib/screens/agenda_screen.dart
//
// Interactive agenda calendar — tap a day to see its reservations.
// Works for both clients (shows provider name) and providers (shows client name).
// Shows only ±14 days by default; a toggle reveals the full month history.
//
// Replaces the flat list in ReservationsTab with a calendar-first view.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/notification_provider.dart';
import '../services/api_services.dart';
import 'chat_screen.dart';

// ── Offer helpers ────────────────────────────────────────────────────────────

const String _offerPrefix = 'OFFER_JSON:';

Map<String, dynamic>? _parseOffer(String content) {
  if (!content.startsWith(_offerPrefix)) return null;
  try { return jsonDecode(content.substring(_offerPrefix.length)); }
  catch (_) { return null; }
}

// ── Reservation model ────────────────────────────────────────────────────────

class AgendaReservation {
  final String description;
  final String date;       // dd/MM/yyyy
  final String time;       // HH:mm
  final String address;
  final String status;     // accepted | completed | reported
  final String partnerName;
  final int    partnerId;
  final int    clientId;
  final int    providerId;
  final bool   isClient;

  const AgendaReservation({
    required this.description,
    required this.date,
    required this.time,
    required this.address,
    required this.status,
    required this.partnerName,
    required this.partnerId,
    required this.clientId,
    required this.providerId,
    required this.isClient,
  });

  /// Parse dd/MM/yyyy + HH:mm → DateTime
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
}

// ─────────────────────────────────────────────────────────────────────────────
// AgendaScreen
// ─────────────────────────────────────────────────────────────────────────────

class AgendaScreen extends StatefulWidget {
  final int    userId;
  final String userRole;

  const AgendaScreen({
    super.key,
    required this.userId,
    required this.userRole,
  });

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen>
    with SingleTickerProviderStateMixin {

  // ── State ─────────────────────────────────────────────────────────────────

  Map<String, List<AgendaReservation>> _byDate = {};
  bool    _loading     = true;
  int     _curYear     = DateTime.now().year;
  int     _curMonth    = DateTime.now().month - 1; // 0-indexed
  String? _selectedKey; // 'yyyy-MM-dd'

  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _load();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (widget.userId == 0) { setState(() => _loading = false); return; }
    setState(() => _loading = true);

    try {
      final conversations = await ApiService.getConversations(
          userId: widget.userId, userType: widget.userRole);

      final Map<String, List<AgendaReservation>> byDate = {};

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

        // Keep only the latest status per offer key
        final Map<String, Map<String, dynamic>> latest = {};
        for (final msg in messages) {
          final offer = _parseOffer(msg['content'] as String? ?? '');
          if (offer == null) continue;
          final key =
              '${offer['description']}|${offer['date']}|${offer['time']}';
          latest[key] = offer;
        }

        for (final offer in latest.values) {
          final status = offer['status'] as String? ?? '';
          if (status != 'accepted' && status != 'completed' &&
              status != 'reported') continue;

          final res = AgendaReservation(
            description: offer['description'] ?? '',
            date:        offer['date']        ?? '',
            time:        offer['time']        ?? '',
            address:     offer['address']     ?? '',
            status:      status,
            partnerName: partnerName,
            partnerId:   partnerId,
            clientId:    clientId,
            providerId:  providerId,
            isClient:    isClient,
          );

          // Build the ISO key for map lookup
          try {
            final dt  = res.dateTime;
            final key =
                '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            byDate.putIfAbsent(key, () => []).add(res);
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() { _byDate = byDate; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _isoKey(int year, int month, int day) =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  bool _dayHasData(int year, int month, int day) {
    final key = _isoKey(year, month + 1, day); // month is 0-indexed internally
    return _byDate.containsKey(key) && (_byDate[key]?.isNotEmpty ?? false);
  }

  bool _dayVisible(int year, int month, int day) =>
      _dayHasData(year, month, day);

  List<AgendaReservation> _reservationsFor(String key) =>
      _byDate[key] ?? [];

  void _selectDay(int day) {
    final key = _isoKey(_curYear, _curMonth + 1, day);
    setState(() => _selectedKey = key);
    _slideCtrl.forward(from: 0);
  }

  void _prevMonth() => setState(() {
    _curMonth--;
    if (_curMonth < 0) { _curMonth = 11; _curYear--; }
    _selectedKey = null;
  });

  void _nextMonth() => setState(() {
    _curMonth++;
    if (_curMonth > 11) { _curMonth = 0; _curYear++; }
    _selectedKey = null;
  });

  void _openChat(AgendaReservation res) {
    Navigator.push(context, chatScreenRoute(
      providerId:   res.providerId,
      providerName: res.partnerName,
      clientId:     res.isClient ? null : res.clientId,
      clientName:   res.isClient ? null : res.partnerName,
    ));
  }

  // ── Month meta ────────────────────────────────────────────────────────────

  static const _monthNames = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];
  static const _monthNamesShort = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  static const _dayNames = [
    'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang        = context.watch<LanguageProvider>();
    final today       = DateTime.now();
    final daysInMonth = DateTime(_curYear, _curMonth + 2, 0).day;
    final firstDow    = DateTime(_curYear, _curMonth + 1, 1).weekday % 7; // Sun=0

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        
        Positioned.fill(
            child: Image.asset('assets/images/bg.png', fit: BoxFit.cover)),
        Positioned.fill(child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.03),
              Colors.white.withOpacity(0.72),
              Colors.white.withOpacity(0.97),
            ],
          )),
        )),

        SafeArea(child: Column(children: [

          // ── Header ────────────────────────────────────────────────────────
          _buildHeader(lang),

          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(
                color: Color(0xFF2A5298), strokeWidth: 2.5))
            : RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFF2A5298),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  slivers: [

                    // ── Calendar card ──────────────────────────────────────
                    SliverToBoxAdapter(child: _buildCalendarCard(
                        today, daysInMonth, firstDow, lang)),

                    // ── Day detail panel ───────────────────────────────────
                    SliverToBoxAdapter(child: _buildDayPanel(lang)),

                    const SliverToBoxAdapter(
                        child: SizedBox(height: 24)),
                  ],
                ),
              )),
        ])),
      ]),
    );
  }

  // ── Header widget ─────────────────────────────────────────────────────────

  Widget _buildHeader(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF1A3A6B), size: 20)),
        const SizedBox(width: 10),
        Text(lang.t('agenda_title'),
          style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w900,
            color: Color(0xFF1A3A6B), letterSpacing: -0.5)),
        const Spacer(),
      ]),
    );
  }

  // ── Calendar card ─────────────────────────────────────────────────────────

  Widget _buildCalendarCard(DateTime today, int daysInMonth, int firstDow,
      LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
          color:      Colors.black.withOpacity(0.08),
          blurRadius: 20, offset: const Offset(0, 6))]),
      child: Column(children: [

        // Month nav
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A3A6B), Color(0xFF2A5298)]),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24))),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_monthNames[_curMonth],
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.3)),
                Text('$_curYear',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.65))),
              ])),
            // Month count badge
            _buildMonthBadge(daysInMonth),
            const SizedBox(width: 12),
            // Nav arrows
            _NavBtn(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
            const SizedBox(width: 6),
            _NavBtn(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
          ]),
        ),

        // Weekday labels
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          child: Row(children: ['S','M','T','W','T','F','S'].map((d) =>
            Expanded(child: Center(child: Text(d,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: Colors.grey.shade400,
                letterSpacing: 0.05))))).toList()),
        ),

        // Grid
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: _buildGrid(today, daysInMonth, firstDow),
        ),

        // Legend
        _buildLegend(lang),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildMonthBadge(int daysInMonth) {
    final count = _byDate.entries.where((e) {
      // Count entries in current month
      try {
        final parts = e.key.split('-');
        return int.parse(parts[0]) == _curYear &&
               int.parse(parts[1]) == _curMonth + 1 &&
               e.value.isNotEmpty;
      } catch (_) { return false; }
    }).length;

    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3))),
      child: Text('$count days',
        style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)));
  }

  Widget _buildGrid(DateTime today, int daysInMonth, int firstDow) {
    final cells = <Widget>[];

    // Empty cells
    for (int i = 0; i < firstDow; i++) {
      cells.add(const SizedBox());
    }

    for (int d = 1; d <= daysInMonth; d++) {
      final isToday   = today.year == _curYear &&
                        today.month == _curMonth + 1 &&
                        today.day  == d;
      final hasData   = _dayVisible(_curYear, _curMonth, d);
      final key       = _isoKey(_curYear, _curMonth + 1, d);
      final isSelected = _selectedKey == key;
      cells.add(_DayCell(
        day:        d,
        isToday:    isToday,
        hasData:    hasData,
        isSelected: isSelected,
        count:      hasData ? (_byDate[key]?.length ?? 0) : 0,
        onTap:      hasData ? () => _selectDay(d) : null,
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }

  Widget _buildLegend(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _LegendDot(color: const Color(0xFF2A5298), label: lang.t('agenda_has_reservation')),
        const SizedBox(width: 16),
        _LegendDot(color: const Color(0xFF10B981), label: lang.t('agenda_completed')),
        const SizedBox(width: 16),
        _LegendDot(color: const Color(0xFFEF4444), label: lang.t('agenda_reported')),
      ]),
    );
  }

  // ── Day detail panel ──────────────────────────────────────────────────────

  Widget _buildDayPanel(LanguageProvider lang) {
    if (_selectedKey == null) return _buildEmptyPrompt(lang);

    final reservations = _reservationsFor(_selectedKey!);
    if (reservations.isEmpty) return _buildEmptyPrompt(lang);

    // Parse selected key for display
    final parts   = _selectedKey!.split('-');
    final year    = int.parse(parts[0]);
    final month   = int.parse(parts[1]);
    final day     = int.parse(parts[2]);
    final dow     = DateTime(year, month, day).weekday % 7;
    final dayName = _dayNames[dow];
    final monthName = _monthNamesShort[month - 1];

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _slideCtrl,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color:      Colors.black.withOpacity(0.07),
              blurRadius: 16, offset: const Offset(0, 4))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Panel header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20))),
              child: Row(children: [
                // Date circle
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF1D9E75)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF0D9488).withOpacity(0.35),
                      blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day',
                        style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: Colors.white, height: 1)),
                      Text(monthName,
                        style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.8),
                          letterSpacing: 0.5)),
                    ])),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dayName,
                      style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: Color(0xFF1A3A6B))),
                    Text('${reservations.length} ${lang.t('agenda_reservations')}',
                      style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
                  ])),
                // Close button
                GestureDetector(
                  onTap: () => setState(() => _selectedKey = null),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: Colors.grey.shade500))),
              ]),
            ),

            // Reservation cards
            ...reservations.asMap().entries.map((entry) {
              final i   = entry.key;
              final res = entry.value;
              return _ResCard(
                reservation: res,
                index:       i,
                lang:        lang,
                onChat:      () => _openChat(res),
              );
            }),

            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyPrompt(LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12, offset: const Offset(0, 3))]),
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color:        const Color(0xFF2A5298).withOpacity(0.07),
            borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.touch_app_rounded,
              color: Color(0xFF2A5298), size: 26)),
        const SizedBox(height: 12),
        Text(lang.t('agenda_tap_day'),
          style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: Color(0xFF1A3A6B))),
        const SizedBox(height: 4),
        Text(lang.t('agenda_tap_day_sub'),
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
          textAlign: TextAlign.center),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAY CELL
// ─────────────────────────────────────────────────────────────────────────────

class _DayCell extends StatefulWidget {
  final int        day;
  final bool       isToday;
  final bool       hasData;
  final bool       isSelected;
  final int        count;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,       required this.isToday,
    required this.hasData,   required this.isSelected,
    required this.count,     this.onTap,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.84)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  Color get _bgColor {
    if (widget.isSelected) return const Color(0xFF0D9488);
    if (widget.hasData)    return const Color(0xFF1A3A6B);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) { if (widget.onTap != null) _pressCtrl.forward(); },
      onTapUp:     (_) { _pressCtrl.reverse(); widget.onTap?.call(); },
      onTapCancel: ()  { _pressCtrl.reverse(); },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
            scale: _scaleAnim.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color:        _bgColor,
            borderRadius: BorderRadius.circular(10),
            border: widget.isToday && !widget.hasData
                ? Border.all(color: const Color(0xFF2A5298), width: 1.5)
                : widget.isSelected
                    ? Border.all(
                        color: Colors.white.withOpacity(0.4), width: 1.5)
                    : null,
            boxShadow: widget.hasData ? [BoxShadow(
              color: (widget.isSelected
                      ? const Color(0xFF0D9488)
                      : const Color(0xFF1A3A6B))
                  .withOpacity(0.30),
              blurRadius: 6, offset: const Offset(0, 3))] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${widget.day}',
                style: TextStyle(
                  fontSize:   widget.hasData ? 13 : 12,
                  fontWeight: widget.hasData || widget.isToday
                      ? FontWeight.w800 : FontWeight.w500,
                  color: widget.hasData
                      ? Colors.white
                      : widget.isToday
                          ? const Color(0xFF1A3A6B)
                          : Colors.grey.shade500,
                  height: 1,
                )),
              if (widget.hasData) ...[
                const SizedBox(height: 3),
                // Dots row — max 4
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.count.clamp(1, 4), (_) =>
                    Container(
                      width: 3.5, height: 3.5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color:  Colors.white.withOpacity(0.75),
                        shape: BoxShape.circle))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESERVATION CARD (inside day panel)
// ─────────────────────────────────────────────────────────────────────────────

class _ResCard extends StatelessWidget {
  final AgendaReservation reservation;
  final int               index;
  final LanguageProvider  lang;
  final VoidCallback      onChat;

  const _ResCard({
    required this.reservation, required this.index,
    required this.lang,        required this.onChat,
  });

  Color get _statusColor {
    switch (reservation.status) {
      case 'completed': return const Color(0xFF10B981);
      case 'reported':  return const Color(0xFFEF4444);
      default:          return const Color(0xFF2A5298);
    }
  }

  IconData get _statusIcon {
    switch (reservation.status) {
      case 'completed': return Icons.check_circle_rounded;
      case 'reported':  return Icons.flag_rounded;
      default:          return Icons.schedule_rounded;
    }
  }

  String _statusLabel(LanguageProvider lang) {
    switch (reservation.status) {
      case 'completed': return lang.t('status_completed');
      case 'reported':  return lang.t('status_reported');
      default:          return lang.t('status_upcoming');
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnerLabel = reservation.isClient
        ? lang.t('provider')
        : lang.t('client');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Color bar
        Container(
          width: 4, height: 56,
          decoration: BoxDecoration(
            color:        _statusColor,
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),

        // Content
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reservation.description,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: Color(0xFF1A3A6B))),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.access_time_rounded,
                  size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(reservation.time,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Icon(Icons.person_outline_rounded,
                  size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Expanded(child: Text(
                '$partnerLabel: ${reservation.partnerName}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500))),
            ]),
            if (reservation.address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.location_on_rounded,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Expanded(child: Text(reservation.address,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5,
                      color: Colors.grey.shade400))),
              ]),
            ],
          ])),

        const SizedBox(width: 10),

        // Right side: status + chat btn
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:        _statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon, color: _statusColor, size: 11),
                const SizedBox(width: 3),
                Text(_statusLabel(lang),
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _statusColor)),
              ])),
            const SizedBox(height: 8),
            // Chat button
            GestureDetector(
              onTap: onChat,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A3A6B), Color(0xFF2A5298)]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF1A3A6B).withOpacity(0.3),
                    blurRadius: 6, offset: const Offset(0, 3))]),
                child: const Icon(Icons.chat_bubble_rounded,
                    color: Colors.white, size: 15))),
          ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.25))),
      child: Icon(icon, color: Colors.white, size: 20)));
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: Colors.grey.shade500)),
    ]);
}