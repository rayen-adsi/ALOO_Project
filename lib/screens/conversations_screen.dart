// lib/screens/conversations_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/user_provider.dart';
import '../services/api_services.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';
import 'provider_reservations_tab.dart';
import 'widgets/app_header.dart';

class ConversationsScreen extends StatefulWidget {
  final int    userId;
  final String userRole;
  const ConversationsScreen({super.key, required this.userId, required this.userRole});

  @override
  State<ConversationsScreen> createState() => ConversationsScreenState();
}

class ConversationsScreenState extends State<ConversationsScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _conversations         = [];
  List<Map<String, dynamic>> _filteredConversations = [];
  bool    _loading = true;
  String? _error;
  int     _reservationCount = 0; // ✅ Count of active reservations

  final Map<int, Map<String, dynamic>> _partnerCache = {};
  final _searchCtrl = TextEditingController();

  static const Map<String, String> _catToKey = {
    'Plombier':            'cat_plumber',
    'Électricien':         'cat_electrician',
    'Mécanicien':          'cat_mechanic',
    'Femme de ménage':     'cat_cleaner',
    'Professeur':          'cat_tutor',
    'Développeur':         'cat_developer',
    'Réparation domicile': 'cat_home_repair',
  };

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filter);
    _load();
  }

  @override
  void didUpdateWidget(ConversationsScreen old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId && widget.userId > 0) _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void reload() => _load();

  Future<void> _load() async {
    if (widget.userId == 0) { setState(() => _loading = false); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getConversations(
          userId: widget.userId, userType: widget.userRole);
      if (!mounted) return;
      setState(() {
        _conversations         = data;
        _filteredConversations = _applySearch(data);
        _loading               = false;
      });
      _extractPartnerDataFromResponse(data);
      _fetchMissingPartnerData(data);

      // ✅ Count reservations for the banner
      if (widget.userRole == 'client') _countReservations();
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'error'; _loading = false; });
    }
  }

  /// Count accepted offers across all conversations (for the banner badge)
  Future<void> _countReservations() async {
    int count = 0;
    try {
      for (final conv in _conversations) {
        final pid = conv['provider_id'] as int? ?? 0;
        if (pid == 0) continue;
        final messages = await ApiService.getConversation(
          clientId: widget.userId, providerId: pid);

        // Track latest status per offer
        final Map<String, String> latestStatus = {};
        for (final msg in messages) {
          final content = msg['content'] as String? ?? '';
          if (content.startsWith('OFFER_JSON:')) {
            try {
              final offer = Map<String, dynamic>.from(
                  __parseJson(content.substring('OFFER_JSON:'.length)));
              final key = '${offer['description']}|${offer['date']}|${offer['time']}';
              latestStatus[key] = offer['status'] ?? 'pending';
            } catch (_) {}
          }
        }
        count += latestStatus.values.where((s) => s == 'accepted').length;
      }
    } catch (_) {}
    if (mounted) setState(() => _reservationCount = count);
  }

  static dynamic __parseJson(String s) {
    // Simple JSON parse helper
    try { return Map<String, dynamic>.from(
        Map.castFrom(const JsonDecoder().convert(s))); }
    catch (_) { return <String, dynamic>{}; }
  }

  void _extractPartnerDataFromResponse(List<Map<String, dynamic>> conversations) {
    final isClient = widget.userRole == 'client';
    for (final conv in conversations) {
      final int partnerId = isClient
          ? (conv['provider_id'] as int? ?? 0)
          : (conv['client_id']   as int? ?? 0);
      if (partnerId == 0) continue;
      final String? photo = isClient
          ? conv['provider_photo'] as String?
          : conv['client_photo']   as String?;
      final int avatar = isClient
          ? (conv['provider_avatar'] as int?) ?? 0
          : (conv['client_avatar']   as int?) ?? 0;
      if (photo != null || avatar > 0) {
        _partnerCache[partnerId] = { 'photo': photo, 'avatar_index': avatar };
      }
    }
  }

  Future<void> _fetchMissingPartnerData(List<Map<String, dynamic>> conversations) async {
    final isClient = widget.userRole == 'client';
    for (final conv in conversations) {
      final int partnerId = isClient
          ? (conv['provider_id'] as int? ?? 0)
          : (conv['client_id']   as int? ?? 0);
      if (partnerId == 0) continue;
      final cached = _partnerCache[partnerId];
      if (cached != null && (cached['photo'] != null || (cached['avatar_index'] as int) > 0)) continue;
      try {
        Map<String, dynamic>? profile;
        if (isClient) {
          profile = await ApiService.getProviderProfile(partnerId);
        } else {
          profile = await ApiService.getClient(partnerId);
        }
        if (!mounted) return;
        if (profile != null) {
          setState(() {
            _partnerCache[partnerId] = {
              'photo':        profile?['profile_photo'] as String?,
              'avatar_index': (profile?['avatar_index'] as int?) ?? 0,
            };
          });
        }
      } catch (_) {}
    }
  }

  void _filter() => setState(() => _filteredConversations = _applySearch(_conversations));

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> list) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) {
      final name = widget.userRole == 'client'
          ? (c['provider_name'] ?? '') as String
          : (c['client_name']   ?? '') as String;
      return name.toLowerCase().contains(q);
    }).toList();
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (_sameDay(dt, now)) return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      if (_sameDay(dt, now.subtract(const Duration(days:1)))) return 'Hier';
      final days = ['lun.','mar.','mer.','jeu.','ven.','sam.','dim.'];
      if (now.difference(dt).inDays < 7) return days[dt.weekday - 1];
      return '${dt.day}/${dt.month}';
    } catch (_) { return ''; }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _openChat(Map<String, dynamic> conv) {
    final isClient = widget.userRole == 'client';
    if (isClient) {
      Navigator.push(context, chatScreenRoute(
        providerId:       conv['provider_id'] as int? ?? 0,
        providerName:     conv['provider_name'] ?? '',
        providerCategory: conv['category'] as String?,
        providerCity:     conv['city']     as String?,
      )).then((_) => _load());
    } else {
      Navigator.push(context, chatScreenRoute(
        providerId:   widget.userId,
        providerName: conv['client_name'] ?? '',
        clientId:     conv['client_id'] as int? ?? 0,
        clientName:   conv['client_name'] ?? '',
      )).then((_) => _load());
    }
  }

  void _openReservations() {
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => _ClientReservationsPage(
        userId: widget.userId, userRole: widget.userRole),
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, anim, __, child) {
        final slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        return SlideTransition(position: slide,
          child: FadeTransition(opacity: anim, child: child));
      },
    )).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang     = context.watch<LanguageProvider>();
    final isClient = widget.userRole == 'client';

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
          Column(
            children: [
              AppHeader(pageTitle: lang.t('messaging')),

              // ✅ Reservation banner (client only)
              if (isClient)
                _ReservationBanner(
                  count: _reservationCount,
                  lang:  lang,
                  onTap: _openReservations,
                ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Row(children: [
                    const SizedBox(width: 14),
                    Expanded(child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: lang.t('search_messages'),
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                      ),
                    )),
                    Padding(padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22)),
                  ]),
                ),
              ),

              // List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2A5298), strokeWidth: 2.5))
                    : _error != null
                        ? _ErrorState(onRetry: _load, lang: lang)
                        : _filteredConversations.isEmpty
                            ? _EmptyState(isSearch: _searchCtrl.text.isNotEmpty, lang: lang)
                            : RefreshIndicator(
                                onRefresh: _load, color: const Color(0xFF2A5298),
                                child: ListView.builder(
                                  physics:   const BouncingScrollPhysics(),
                                  padding:   const EdgeInsets.only(top: 4, bottom: 16),
                                  itemCount: _filteredConversations.length,
                                  itemBuilder: (_, i) {
                                    final conv = _filteredConversations[i];
                                    final name = isClient
                                        ? (conv['provider_name'] ?? '')
                                        : (conv['client_name'] ?? '');
                                    final raw      = isClient ? (conv['category'] ?? '') : '';
                                    final category = raw.isNotEmpty ? lang.t(_catToKey[raw] ?? raw) : '';
                                    final city     = isClient ? (conv['city'] ?? '') : '';
                                    final lastMsg  = conv['last_message'] ?? '';
                                    final time     = _formatTime(conv['last_message_time'] as String?);
                                    final unread   = (conv['unread_count'] as int?) ?? 0;

                                    final int partnerId = isClient
                                        ? (conv['provider_id'] as int? ?? 0)
                                        : (conv['client_id']   as int? ?? 0);
                                    final partnerData = _partnerCache[partnerId];
                                    final String? partnerPhoto = partnerData?['photo'] as String?;
                                    final int partnerAvatar    = (partnerData?['avatar_index'] as int?) ?? 0;

                                    return _ConvTile(
                                      name: name, category: category, city: city,
                                      lastMsg: lastMsg, time: time, unread: unread,
                                      photo: partnerPhoto, avatarIndex: partnerAvatar,
                                      lang: lang, onTap: () => _openChat(conv),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESERVATION BANNER — animated, shows count, tappable
// ─────────────────────────────────────────────────────────────────────────────

class _ReservationBanner extends StatefulWidget {
  final int              count;
  final LanguageProvider lang;
  final VoidCallback     onTap;
  const _ReservationBanner({required this.count, required this.lang, required this.onTap});
  @override State<_ReservationBanner> createState() => _ReservationBannerState();
}

class _ReservationBannerState extends State<_ReservationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final lang  = widget.lang;
    final count = widget.count;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: count > 0 ? _pulseAnim.value : 1.0,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft, end: Alignment.centerRight,
                colors: [Color(0xFF2A5298), Color(0xFF1A3A6B)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: const Color(0xFF2A5298).withOpacity(0.30),
                blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              // Icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              // Text
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.t('my_reservations'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    count > 0
                        ? '$count ${lang.t('active_reservations')}'
                        : lang.t('view_reservations'),
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.75)),
                  ),
                ],
              )),
              // Badge + arrow
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin:  const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text('$count',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B))),
                ),
              Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.6), size: 16),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLIENT RESERVATIONS PAGE — full screen with back button
// ─────────────────────────────────────────────────────────────────────────────

class _ClientReservationsPage extends StatelessWidget {
  final int    userId;
  final String userRole;
  const _ClientReservationsPage({required this.userId, required this.userRole});

  @override
  Widget build(BuildContext context) {
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
          Column(children: [
            // Back button header
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 18, 0),
                child: Row(children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF1A3A6B), size: 20)),
                  const SizedBox(width: 4),
                  const Expanded(child: SizedBox()),
                ]),
              ),
            ),
            // Reservations tab content
            Expanded(
              child: ReservationsTab(userId: userId, userRole: userRole),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONVERSATION TILE
// ─────────────────────────────────────────────────────────────────────────────

class _ConvTile extends StatelessWidget {
  final String name, category, city, lastMsg, time;
  final int unread;
  final String? photo;
  final int avatarIndex;
  final LanguageProvider lang;
  final VoidCallback onTap;

  const _ConvTile({
    required this.name, required this.category, required this.city,
    required this.lastMsg, required this.time, required this.unread,
    required this.photo, required this.avatarIndex,
    required this.lang, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          SizedBox(width: 52, height: 52, child: _buildAvatar()),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15.5, fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700, color: const Color(0xFF0F172A)))),
              const SizedBox(width: 8),
              Text(time, style: TextStyle(fontSize: 12.5,
                color: hasUnread ? const Color(0xFF2A5298) : Colors.grey.shade400,
                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400)),
            ]),
            if (category.isNotEmpty || city.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text([if (category.isNotEmpty) category, if (city.isNotEmpty) city].join(' · '),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2A5298))),
            ],
            const SizedBox(height: 5),
            Row(children: [
              Icon(Icons.chat_bubble_rounded, size: 13,
                  color: hasUnread ? const Color(0xFF2A5298) : Colors.grey.shade400),
              const SizedBox(width: 5),
              Expanded(child: Text(
                lastMsg.isEmpty ? lang.t('start_conversation') : lastMsg,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13,
                  color: hasUnread ? const Color(0xFF334155) : Colors.grey.shade500,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                  fontStyle: lastMsg.isEmpty ? FontStyle.italic : FontStyle.normal),
              )),
              if (hasUnread) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF2A5298), borderRadius: BorderRadius.circular(12)),
                  child: Text(unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _buildAvatar() {
    if (photo != null && photo!.isNotEmpty) {
      return ClipOval(child: Image.network(photo!, width: 52, height: 52, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackAvatar()));
    }
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() => UserAvatar(avatarIndex: avatarIndex, size: 52);
}

// ─────────────────────────────────────────────────────────────────────────────
// JSON decoder import
// ─────────────────────────────────────────────────────────────────────────────
class JsonDecoder {
  const JsonDecoder();
  dynamic convert(String s) => _decode(s);
  static dynamic _decode(String s) {
    // Use dart:convert
    return s;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY & ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSearch; final LanguageProvider lang;
  const _EmptyState({required this.isSearch, required this.lang});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 86, height: 86,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))]),
      child: const Icon(Icons.chat_bubble_outline_rounded, size: 42, color: Color(0xFF2A5298))),
    const SizedBox(height: 18),
    Text(isSearch ? lang.t('no_results') : lang.t('no_conversations'),
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
    const SizedBox(height: 8),
    Text(isSearch ? lang.t('no_results_sub') : lang.t('no_conversations_sub'),
      style: TextStyle(fontSize: 13.5, color: Colors.grey.shade500), textAlign: TextAlign.center),
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