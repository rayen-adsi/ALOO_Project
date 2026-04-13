// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/notification_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import '../core/user_provider.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'provider_profile_screen.dart';
import 'chat_screen.dart';
import 'favorites_screen.dart';
import 'conversations_screen.dart';
import 'notifications_screen.dart';
import 'widgets/app_header.dart';

class homeScreen extends StatefulWidget {
  final String fullName;
  const homeScreen({super.key, this.fullName = ''});

  @override
  State<homeScreen> createState() => _homeScreenState();
}

class _homeScreenState extends State<homeScreen>
    with SingleTickerProviderStateMixin {
  int _currentNav = 0;
  final _favKey  = GlobalKey<FavoritesScreenState>();
  final _convKey = GlobalKey<ConversationsScreenState>();

  late final AnimationController _entryCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _searchFade;
  late final Animation<Offset> _searchSlide;
  late final Animation<double> _catFade;
  late final Animation<double> _cardsFade;
  late final Animation<Offset> _cardsSlide;

  List<Map<String, dynamic>> _providers         = [];
  List<Map<String, dynamic>> _filteredProviders = [];
  bool    _loadingProviders = true;
  String? _providersError;

  final _searchCtrl     = TextEditingController();
  String? _selectedCategory;

  int    _userId      = 0;
  String _userRole    = 'client';
  int    _avatarIndex = 0;

  static const Map<String, Color> _categoryColors = {
    'Plombier':            Color(0xFF1A6B9A),
    'Électricien':         Color(0xFFF59E0B),
    'Mécanicien':          Color(0xFF64748B),
    'Femme de ménage':     Color(0xFFEC4899),
    'Professeur':          Color(0xFF10B981),
    'Développeur':         Color(0xFF8B5CF6),
    'Réparation domicile': Color(0xFF4A3580),
  };

  static const Map<String, String> _categoryToKey = {
    'Plombier':            'cat_plumber',
    'Électricien':         'cat_electrician',
    'Mécanicien':          'cat_mechanic',
    'Femme de ménage':     'cat_cleaner',
    'Professeur':          'cat_tutor',
    'Développeur':         'cat_developer',
    'Réparation domicile': 'cat_home_repair',
  };

  static const Map<String, String> _keyToCategory = {
    'cat_plumber':     'Plombier',
    'cat_electrician': 'Électricien',
    'cat_mechanic':    'Mécanicien',
    'cat_cleaner':     'Femme de ménage',
    'cat_tutor':       'Professeur',
    'cat_developer':   'Développeur',
    'cat_home_repair': 'Réparation domicile',
  };

  static const List<Map<String, dynamic>> _categories = [
    {'key': 'cat_plumber',     'icon': Icons.water_drop_outlined,          'color': Color(0xFF0EA5E9)},
    {'key': 'cat_electrician', 'icon': Icons.bolt_outlined,                'color': Color(0xFFF59E0B)},
    {'key': 'cat_mechanic',    'icon': Icons.build_outlined,               'color': Color(0xFF64748B)},
    {'key': 'cat_home_repair', 'icon': Icons.home_repair_service_outlined, 'color': Color(0xFF10B981)},
    {'key': 'cat_cleaner',     'icon': Icons.cleaning_services_outlined,   'color': Color(0xFFEC4899)},
  ];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _headerFade  = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.00, 0.45, curve: Curves.easeOut));
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.00, 0.50, curve: Curves.easeOutCubic)));
    _searchFade  = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.15, 0.55, curve: Curves.easeOut));
    _searchSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic)));
    _catFade     = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.30, 0.70, curve: Curves.easeOut));
    _cardsFade   = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.45, 1.00, curve: Curves.easeOut));
    _cardsSlide  = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.45, 1.00, curve: Curves.easeOutCubic)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryCtrl.forward();
      _loadSession();
    });
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final session = await UserSession.load();
    if (!mounted) return;
    setState(() {
      _userId      = session['id']           ?? 0;
      _userRole    = session['role']         ?? 'client';
      _avatarIndex = session['avatar_index'] ?? 0;
    });
    await _fetchProviders();
  }

  Future<void> _fetchProviders() async {
    setState(() { _loadingProviders = true; _providersError = null; });
    try {
      final data = await ApiService.getProviders();
      if (!mounted) return;
      final mapped = _mapProviders(data);
      setState(() { _providers = mapped; _filteredProviders = mapped; _loadingProviders = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _providersError = 'Could not load providers'; _loadingProviders = false; });
    }
  }

  List<Map<String, dynamic>> _mapProviders(List<Map<String, dynamic>> data) {
    return data.map((p) {
      final category = p['category'] as String? ?? '';
      return {
        'id':             p['id']            ?? 0,
        'name':           p['full_name']     ?? '',
        'job_key':        _categoryToKey[category] ?? 'cat_home_repair',
        'category':       category,
        'city':           p['city']          ?? '',
        'rating':         (p['rating'] as num?)?.toDouble() ?? 0.0,
        'top':            p['is_verified']   == true,
        'color':          _categoryColors[category] ?? const Color(0xFF1A6B9A),
        'profile_photo':  p['profile_photo'],
        'total_reviews':  p['total_reviews'] ?? 0,
        'score':          (p['score'] as int?) ?? 0,
        'completed_jobs': (p['completed_jobs'] as int?) ?? 0,
      };
    }).toList();
  }

  void _onCategoryTap(String key) {
    final category = _keyToCategory[key];
    setState(() { _selectedCategory = _selectedCategory == category ? null : category; });
    _applyFilters();
  }

  void _applyFilters() {
    final q   = _searchCtrl.text.trim().toLowerCase();
    final cat = _selectedCategory;
    setState(() {
      _filteredProviders = _providers.where((p) {
        final matchQ   = q.isEmpty || (p['name'] as String).toLowerCase().contains(q) || (p['city'] as String).toLowerCase().contains(q);
        final matchCat = cat == null || p['category'] == cat;
        return matchQ && matchCat;
      }).toList();
    });
  }

  Future<void> _searchFromBackend(String q) async {
    if (q.length < 2) { _applyFilters(); return; }
    try {
      final data = await ApiService.searchProviders(q: q, category: _selectedCategory);
      if (!mounted) return;
      setState(() => _filteredProviders = _mapProviders(data));
    } catch (_) {}
  }

  void _goToProfile(Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ProviderProfileScreen(providerId: data['id'] as int)));
  }

  void _goToChat(Map<String, dynamic> data) {
    Navigator.push(context, chatScreenRoute(
      providerId:       data['id'] as int,
      providerName:     data['name'] as String,
      providerCategory: data['category'] as String?,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final List<Widget> tabs = [
      _buildHomeTab(lang),
      FavoritesScreen(key: _favKey, clientId: _userId),
      const Center(child: Icon(Icons.location_on_outlined, size: 60, color: Colors.grey)),
      ConversationsScreen(key: _convKey, userId: _userId, userRole: _userRole),
      const SettingsScreen(),
    ];
    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: IndexedStack(index: _currentNav, children: tabs),
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentNav,
          onTap: (i) {
            setState(() => _currentNav = i);
            if (i == 1) _favKey.currentState?.reload();
            if (i == 3) _convKey.currentState?.reload();
          },
        ),
      ),
    );
  }

  Widget _buildHomeTab(LanguageProvider lang) {
    return Stack(
      children: [
        Positioned.fill(child: Image.asset('assets/images/bg.png', fit: BoxFit.cover)),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end:   Alignment.bottomCenter,
                colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.75), Colors.white.withOpacity(0.95)],
              ),
            ),
          ),
        ),
        Column(
          children: [
            _TopBar(
              fadeAnim:  _headerFade,
              slideAnim: _headerSlide,
              lang:      lang,
              userId:    _userId,
              onAvatarTap: () async {
                final updated = await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                if (updated == true && mounted) {
                  await context.read<UserProvider>().load();
                  _loadSession();
                }
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeTransition(opacity: _searchFade, child: SlideTransition(position: _searchSlide,
                        child: _SearchBar(lang: lang, controller: _searchCtrl, onSubmitted: _searchFromBackend))),
                    FadeTransition(opacity: _catFade,
                        child: _CategoriesRow(categories: _categories, lang: lang,
                            selectedCategory: _selectedCategory != null
                                ? _categoryToKey.entries.firstWhere(
                                    (e) => e.value == _selectedCategory,
                                    orElse: () => const MapEntry('', '')).key
                                : null,
                            onTap: _onCategoryTap)),
                    FadeTransition(
                      opacity: _cardsFade,
                      child: SlideTransition(
                        position: _cardsSlide,
                        child: _loadingProviders
                            ? const Padding(padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(child: CircularProgressIndicator(color: Color(0xFF2A5298), strokeWidth: 2.5)))
                            : _providersError != null
                                ? Padding(padding: const EdgeInsets.all(24), child: Column(children: [
                                    Icon(Icons.wifi_off_rounded, color: Colors.grey.shade400, size: 40),
                                    const SizedBox(height: 10),
                                    Text(_providersError!, style: TextStyle(color: Colors.grey.shade500)),
                                    const SizedBox(height: 12),
                                    TextButton(onPressed: _fetchProviders, child: const Text('Retry'))]))
                                : _RecommendedSection(
                                    providers: _filteredProviders, lang: lang,
                                    onCardTap: _goToProfile, onContact: _goToChat),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR — with notification bell
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final LanguageProvider  lang;
  final int               userId;
  final VoidCallback      onAvatarTap;

  const _TopBar({
    required this.fadeAnim,
    required this.slideAnim,
    required this.lang,
    required this.userId,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(
        position: slideAnim,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: Row(
              children: [
                Image.asset('assets/images/aloo_logo.png',
                    height: 60, fit: BoxFit.contain),
                const Spacer(),
                if (user.fullName.isNotEmpty)
                  Text(user.fullName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(width: 10),

                // 🔔 Notification bell
                NotifBellWidget(unreadCount: context.watch<NotificationProvider>().unreadCount),
                const SizedBox(width: 10),

                UserAvatar(
                  avatarIndex: user.avatarIndex,
                  photoPath:   user.photoPath,
                  size:        40,
                  onTap:       onAvatarTap,
                  showBorder:  true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION BELL — reusable for pages without AppHeader
// ─────────────────────────────────────────────────────────────────────────────

class _NotifBell extends StatefulWidget {
  final int    userId;
  final String userType;
  const _NotifBell({required this.userId, required this.userType});

  @override
  State<_NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<_NotifBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId == 0) return;
    try {
      final notifs = await ApiService.getNotifications(
          userId: widget.userId, userType: widget.userType);
      if (!mounted) return;
      setState(() =>
          _unread = notifs.where((n) => n['is_read'] == false).length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const NotificationsScreen(),
            transitionDuration: const Duration(milliseconds: 320),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: child),
          ),
        );
        _load(); // refresh badge when returning
      },
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color:  Colors.white.withOpacity(0.18),
            shape:  BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.30), width: 1)),
          child: const Icon(Icons.notifications_rounded,
              color: Colors.white, size: 20)),
        if (_unread > 0)
          Positioned(
            top: -2, right: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color:        const Color(0xFFEF4444),
                shape:        _unread < 10 ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: _unread < 10 ? null : BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1.5)),
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                    color: Colors.white, height: 1.1),
                textAlign: TextAlign.center))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final LanguageProvider      lang;
  final TextEditingController controller;
  final ValueChanged<String>  onSubmitted;
  const _SearchBar({required this.lang, required this.controller, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 4))]),
        child: TextField(
          controller:  controller,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText:  lang.t('search_placeholder'),
            hintStyle: TextStyle(fontSize: 14.5, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
            prefixIcon: Icon(Icons.search_rounded, color: const Color(0xFF2A5298).withOpacity(0.7), size: 22),
            border:         InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORIES ROW
// ─────────────────────────────────────────────────────────────────────────────

class _CategoriesRow extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final LanguageProvider           lang;
  final String?                    selectedCategory;
  final ValueChanged<String>       onTap;
  const _CategoriesRow({required this.categories, required this.lang, required this.selectedCategory, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: categories.map((cat) {
            final key      = cat['key'] as String;
            final isActive = selectedCategory == key;
            return _CategoryChip(
              icon:     cat['icon'] as IconData,
              label:    lang.t(key),
              color:    cat['color'] as Color,
              isActive: isActive,
              onTap:    () => onTap(key));
          }).toList(),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  final IconData icon; final String label; final Color color; final bool isActive; final VoidCallback onTap;
  const _CategoryChip({required this.icon, required this.label, required this.color, required this.isActive, required this.onTap});
  @override State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:       widget.onTap,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0, duration: const Duration(milliseconds: 130),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:        widget.isActive ? widget.color.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border:       widget.isActive ? Border.all(color: widget.color, width: 1.5) : null,
            boxShadow: [BoxShadow(color: widget.color.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(color: widget.color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(widget.icon, color: widget.color, size: 22)),
            const SizedBox(height: 6),
            Text(widget.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                color: widget.isActive ? widget.color : const Color(0xFF1E293B))),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECOMMENDED SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendedSection extends StatelessWidget {
  final List<Map<String, dynamic>>         providers;
  final LanguageProvider                   lang;
  final ValueChanged<Map<String, dynamic>> onCardTap;
  final ValueChanged<Map<String, dynamic>> onContact;
  const _RecommendedSection({required this.providers, required this.lang, required this.onCardTap, required this.onContact});

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [
        Icon(Icons.search_off_rounded, color: Colors.grey.shade400, size: 48),
        const SizedBox(height: 12),
        Text(lang.t('no_providers_found'), style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600))])));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 20, decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A3A6B), Color(0xFF2A5298)]),
              borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 10),
            Text(lang.t('recommended'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          ]),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.70),
            itemCount: providers.length,
            itemBuilder: (_, i) => _ProviderCard(
              data:      providers[i],
              lang:      lang,
              onCardTap: () => onCardTap(providers[i]),
              onContact: () => onContact(providers[i])),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER CARD — with score tier badge
// ─────────────────────────────────────────────────────────────────────────────

class _ProviderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final LanguageProvider     lang;
  final VoidCallback         onCardTap;
  final VoidCallback         onContact;
  const _ProviderCard({required this.data, required this.lang, required this.onCardTap, required this.onContact});

  // Determine tier badge from score
  _TierBadge? _getTierBadge() {
    final score = (data['score'] as int?) ?? 0;
    if (score >= 100) return const _TierBadge(label: '👑 Elite',   color: Color(0xFFF59E0B));
    if (score >= 60)  return const _TierBadge(label: '🏆 Top',     color: Color(0xFF2A5298));
    if (score >= 30)  return const _TierBadge(label: '⭐ Rising',  color: Color(0xFF10B981));
    return null; // no badge for new providers
  }

  @override
  Widget build(BuildContext context) {
    final bool isTop    = data['top'] as bool;
    final Color color   = data['color'] as Color;
    final double rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final tier = _getTierBadge();

    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 6))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar area
            Stack(children: [
              Container(
                height: 110, width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [color.withOpacity(0.85), color]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
                child: data['profile_photo'] != null
                    ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        child: Image.network(data['profile_photo'], fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Colors.white54, size: 56)))
                    : const Icon(Icons.person_rounded, color: Colors.white54, size: 56),
              ),
              // Verified badge
              if (isTop) Positioned(top: 8, left: 8, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.verified_rounded, color: Colors.white, size: 11),
                  const SizedBox(width: 3),
                  Text(lang.t('top_provider'), style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                ]))),
              // Score tier badge
              if (tier != null) Positioned(top: 8, right: 8, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: tier.color.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: tier.color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))]),
                child: Text(tier.label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))),
            ]),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(lang.t(data['job_key'] as String),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                          color: const Color(0xFF374757).withOpacity(0.85))),
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 14),
                    const SizedBox(width: 3),
                    Text(rating > 0 ? rating.toStringAsFixed(1) : 'New',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF7D7D7D))),
                    const SizedBox(width: 6),
                    const Icon(Icons.location_on_rounded, color: Color(0xFF7D7D7D), size: 12),
                    const SizedBox(width: 2),
                    Expanded(child: Text(data['city'] as String, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF7D7D7D), fontWeight: FontWeight.w600))),
                  ]),
                  const Spacer(),

                  // Buttons
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: onContact, behavior: HitTestBehavior.opaque,
                      child: Container(height: 30,
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF2174FC), width: 1.3), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text(lang.t('contact'), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2174FC))))))),
                    const SizedBox(width: 6),
                    Expanded(child: GestureDetector(
                      onTap: onCardTap, behavior: HitTestBehavior.opaque,
                      child: Container(height: 30,
                        decoration: BoxDecoration(color: const Color(0xFF2174FC), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text(lang.t('view_profile'), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)))))),
                  ]),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierBadge {
  final String label;
  final Color  color;
  const _TierBadge({required this.label, required this.color});
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      {'icon': Icons.home_outlined,               'active': Icons.home_rounded},
      {'icon': Icons.favorite_border_rounded,     'active': Icons.favorite_rounded},
      {'icon': Icons.location_on_outlined,        'active': Icons.location_on_rounded},
      {'icon': Icons.chat_bubble_outline_rounded, 'active': Icons.chat_bubble_rounded},
      {'icon': Icons.settings_outlined,           'active': Icons.settings_rounded},
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))]),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = currentIndex == i;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(width: 52, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  AnimatedContainer(duration: const Duration(milliseconds: 200),
                      width: isActive ? 40 : 0, height: isActive ? 4 : 0,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4))),
                  Icon(isActive ? items[i]['active'] as IconData : items[i]['icon'] as IconData,
                      color: Colors.black, size: 24),
                ])),
              );
            }),
          ),
        ),
      ),
    );
  }
}