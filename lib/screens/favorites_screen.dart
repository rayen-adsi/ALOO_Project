// lib/screens/favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/user_provider.dart';
import '../services/api_services.dart';
import 'chat_screen.dart';
import 'provider_profile_screen.dart';
import 'widgets/app_header.dart';
import 'edit_profile_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final int clientId;
  const FavoritesScreen({super.key, required this.clientId});
  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

class FavoritesScreenState extends State<FavoritesScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _favorites = [];
  bool    _loading = true;
  String? _error;

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
    _load();
  }

  @override
  void didUpdateWidget(FavoritesScreen old) {
    super.didUpdateWidget(old);
    if (old.clientId != widget.clientId && widget.clientId > 0) _load();
  }

  void reload() => _load();

  Future<void> _load() async {
    if (widget.clientId == 0) { setState(() => _loading = false); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getFavorites(widget.clientId);
      if (!mounted) return;
      setState(() { _favorites = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'error'; _loading = false; });
    }
  }

  Future<void> _remove(int providerId) async {
    setState(() => _favorites.removeWhere((f) => f['id'] == providerId));
    try {
      await ApiService.removeFavorite(clientId: widget.clientId, providerId: providerId);
    } catch (_) { _load(); }
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
              // Header with avatar + favorites title
              AppHeader(
                pageTitle: null,
                customTitle: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]),
                    child: const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 20)),
                  const SizedBox(width: 10),
                  Text(lang.t('favorites'), style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900,
                    color: Color(0xFF1A3A6B), letterSpacing: -0.5)),
                ]),
              ),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2A5298), strokeWidth: 2.5))
                    : _error != null
                        ? _ErrorState(onRetry: _load, lang: lang)
                        : _favorites.isEmpty
                            ? _EmptyState(lang: lang)
                            : RefreshIndicator(
                                onRefresh: _load, color: const Color(0xFF2A5298),
                                child: ListView.builder(
                                  physics:   const BouncingScrollPhysics(),
                                  padding:   const EdgeInsets.fromLTRB(16, 4, 16, 20),
                                  itemCount: _favorites.length,
                                  itemBuilder: (_, i) {
                                    final p = _favorites[i];
                                    return _FavCard(
                                      provider: p, lang: lang, catToKey: _catToKey,
                                      onRemove: () => _remove(p['id'] as int),
                                      onContact: () => Navigator.push(context, chatScreenRoute(
                                        providerId:       p['id'] as int,
                                        providerName:     p['full_name'] ?? '',
                                        providerCategory: p['category'] as String?,
                                        providerCity:     p['city']     as String?,
                                      )),
                                      onProfile: () => Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => ProviderProfileScreen(providerId: p['id'] as int))),
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

class _FavCard extends StatefulWidget {
  final Map<String, dynamic> provider;
  final LanguageProvider lang;
  final Map<String, String> catToKey;
  final VoidCallback onRemove, onContact, onProfile;
  const _FavCard({required this.provider, required this.lang, required this.catToKey,
      required this.onRemove, required this.onContact, required this.onProfile});
  @override
  State<_FavCard> createState() => _FavCardState();
}

class _FavCardState extends State<_FavCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p        = widget.provider;
    final name     = p['full_name']    as String? ?? '';
    final category = p['category']     as String? ?? '';
    final city     = p['city']         as String? ?? '';
    final rating   = (p['rating'] as num?)?.toDouble() ?? 0.0;
    final photo    = p['profile_photo'] as String?;
    final catKey   = widget.catToKey[category] ?? '';
    final catLabel = catKey.isNotEmpty ? widget.lang.t(catKey) : category;

    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.transparent,
            child: Column(children: [
              // Top — tappable → profile
              InkWell(
                onTap: widget.onProfile,
                onTapDown: (_) => _ctrl.forward(),
                onTapUp:   (_) => _ctrl.reverse(),
                onTapCancel: () => _ctrl.reverse(),
                splashColor: const Color(0xFF2A5298).withOpacity(0.06),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: photo != null
                          ? Image.network(photo, width: 90, height: 90, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _AvatarFallback(name: name))
                          : _AvatarFallback(name: name),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(height: 3),
                      Text(catLabel, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
                        const SizedBox(width: 4),
                        Text(rating > 0 ? rating.toStringAsFixed(1) : 'New',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_on_rounded, color: Color(0xFF94A3B8), size: 14),
                        const SizedBox(width: 3),
                        Text(city, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      ]),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 22),
                  ]),
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade100),
              // Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(children: [
                  Expanded(child: _CardBtn(label: widget.lang.t('contact'), color: const Color(0xFF2174FC), textColor: Colors.white, onTap: widget.onContact)),
                  const SizedBox(width: 8),
                  Expanded(child: _CardBtn(label: widget.lang.t('view_profile'), color: const Color(0xFF2174FC), textColor: Colors.white, onTap: widget.onProfile)),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _CardBtn(
                    label: widget.lang.t('remove_favorite'), color: const Color(0xFFEF4444),
                    textColor: Colors.white, icon: Icons.favorite_rounded, onTap: widget.onRemove)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CardBtn extends StatefulWidget {
  final String label; final Color color, textColor; final IconData? icon; final VoidCallback onTap;
  const _CardBtn({required this.label, required this.color, required this.textColor, this.icon, required this.onTap});
  @override State<_CardBtn> createState() => _CardBtnState();
}

class _CardBtnState extends State<_CardBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => setState(() => _pressed = true),
    onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 36,
      decoration: BoxDecoration(
        color:        _pressed ? widget.color.withOpacity(0.80) : widget.color,
        borderRadius: BorderRadius.circular(10),
        boxShadow:    _pressed ? [] : [BoxShadow(color: widget.color.withOpacity(0.30), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (widget.icon != null) ...[Icon(widget.icon, color: widget.textColor, size: 13), const SizedBox(width: 4)],
        Text(widget.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: widget.textColor)),
      ]),
    ),
  );
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  const _AvatarFallback({required this.name});
  @override
  Widget build(BuildContext context) => Container(
    width: 90, height: 90,
    decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF2A5298), Color(0xFF1A3A6B)])),
    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white))),
  );
}

class _EmptyState extends StatelessWidget {
  final LanguageProvider lang;
  const _EmptyState({required this.lang});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 86, height: 86,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))]),
      child: const Icon(Icons.favorite_border_rounded, size: 42, color: Color(0xFF2A5298))),
    const SizedBox(height: 18),
    Text(lang.t('no_favorites'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
    const SizedBox(height: 8),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(lang.t('no_favorites_sub'), style: TextStyle(fontSize: 13.5, color: Colors.grey.shade500), textAlign: TextAlign.center)),
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
    TextButton(onPressed: onRetry, child: Text(lang.t('retry'),
      style: const TextStyle(color: Color(0xFF2A5298), fontWeight: FontWeight.w700))),
  ]));
}