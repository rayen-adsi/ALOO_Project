// lib/screens/conversations_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/user_provider.dart';
import '../services/api_services.dart';
import 'chat_screen.dart';
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
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'error'; _loading = false; });
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
    Navigator.push(context, chatScreenRoute(
      providerId:       isClient ? (conv['provider_id'] as int? ?? 0) : widget.userId,
      providerName:     isClient ? (conv['provider_name'] ?? '') : (conv['client_name'] ?? ''),
      providerCategory: isClient ? (conv['category'] as String?) : null,
      providerCity:     isClient ? (conv['city']     as String?) : null,
    )).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = context.watch<LanguageProvider>();

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
              // Header with avatar
              AppHeader(pageTitle: lang.t('messaging')),

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
                                    final conv     = _filteredConversations[i];
                                    final isClient = widget.userRole == 'client';
                                    final name     = isClient ? (conv['provider_name'] ?? '') : (conv['client_name'] ?? '');
                                    final raw      = isClient ? (conv['category'] ?? '') : '';
                                    final category = raw.isNotEmpty ? lang.t(_catToKey[raw] ?? raw) : '';
                                    final city     = isClient ? (conv['city'] ?? '') : '';
                                    final lastMsg  = conv['last_message'] ?? '';
                                    final time     = _formatTime(conv['last_message_time'] as String?);
                                    final unread   = (conv['unread_count'] as int?) ?? 0;
                                    return _ConvTile(
                                      name: name, category: category, city: city,
                                      lastMsg: lastMsg, time: time, unread: unread,
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

class _ConvTile extends StatelessWidget {
  final String name, category, city, lastMsg, time;
  final int unread;
  final LanguageProvider lang;
  final VoidCallback onTap;
  const _ConvTile({required this.name, required this.category, required this.city,
      required this.lastMsg, required this.time, required this.unread,
      required this.lang, required this.onTap});

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
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF3B82F6), Color(0xFF1A3A6B)]),
              boxShadow: [BoxShadow(color: const Color(0xFF2A5298).withOpacity(0.22), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Center(child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white),
            )),
          ),
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
}

class _EmptyState extends StatelessWidget {
  final bool isSearch;
  final LanguageProvider lang;
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
  final VoidCallback onRetry;
  final LanguageProvider lang;
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