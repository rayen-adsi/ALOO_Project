// lib/screens/favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../services/api_services.dart';
import 'provider_profile_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final int clientId;
  const FavoritesScreen({super.key, this.clientId = 0});

  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

class FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, dynamic>> _favorites = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.clientId > 0) _loadFavorites();
    else setState(() => _loading = false);
  }

  @override
  void didUpdateWidget(FavoritesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Session just loaded — now we have a real clientId
    if (oldWidget.clientId == 0 && widget.clientId > 0) {
      _loadFavorites();
    }
  }

  // Public method called by home_screen when tab is tapped
  Future<void> reload() => _loadFavorites();

  Future<void> _loadFavorites() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getFavorites(widget.clientId);
      if (!mounted) return;
      setState(() { _favorites = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Could not load favorites'; _loading = false; });
    }
  }

  Future<void> _removeFavorite(int providerId) async {
    await ApiService.removeFavorite(
        clientId: widget.clientId, providerId: providerId);
    if (!mounted) return;
    setState(() => _favorites.removeWhere((f) => f['id'] == providerId));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from favorites')));
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
              child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
            ),
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
                  // ── Header ─────────────────────────────────────────
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
                        Text(
                          lang.t('favorites'),
                          style: const TextStyle(fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A3A6B)),
                        ),
                        const Spacer(),
                        if (_favorites.isNotEmpty)
                          Text('${_favorites.length} saved',
                            style: TextStyle(fontSize: 13,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                  // ── Content ────────────────────────────────────────
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
                                  TextButton(
                                      onPressed: _loadFavorites,
                                      child: const Text('Retry')),
                                ],
                              ))
                            : _favorites.isEmpty
                                ? _EmptyState()
                                : RefreshIndicator(
                                    onRefresh: _loadFavorites,
                                    color: const Color(0xFF2A5298),
                                    child: ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                      itemCount: _favorites.length,
                                      itemBuilder: (_, i) => _FavoriteCard(
                                        provider: _favorites[i],
                                        onTap: () => Navigator.push(context,
                                          MaterialPageRoute(builder: (_) =>
                                            ProviderProfileScreen(
                                              providerId: _favorites[i]['id'] as int))),
                                        onRemove: () => _removeFavorite(
                                            _favorites[i]['id'] as int),
                                      ),
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
            child: const Icon(Icons.favorite_border_rounded,
                color: Color(0xFF2A5298), size: 42),
          ),
          const SizedBox(height: 16),
          const Text('No favorites yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: Color(0xFF1A3A6B))),
          const SizedBox(height: 6),
          Text('Tap the heart on any provider\nto save them here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _FavoriteCard extends StatefulWidget {
  final Map<String, dynamic> provider;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteCard({
    required this.provider,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_FavoriteCard> createState() => _FavoriteCardState();
}

class _FavoriteCardState extends State<_FavoriteCard> {
  bool _pressed = false;

  static const Map<String, Color> _categoryColors = {
    'Plombier':            Color(0xFF1A6B9A),
    'Électricien':         Color(0xFFF59E0B),
    'Mécanicien':          Color(0xFF64748B),
    'Femme de ménage':     Color(0xFFEC4899),
    'Professeur':          Color(0xFF10B981),
    'Développeur':         Color(0xFF8B5CF6),
    'Réparation domicile': Color(0xFF4A3580),
  };

  @override
  Widget build(BuildContext context) {
    final p     = widget.provider;
    final color = _categoryColors[p['category'] as String? ?? '']
        ?? const Color(0xFF1A6B9A);
    final double rating = (p['rating'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07),
                blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [color.withOpacity(0.8), color]),
                ),
                child: p['profile_photo'] != null
                    ? ClipOval(child: Image.network(p['profile_photo'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded, color: Colors.white, size: 30)))
                    : const Icon(Icons.person_rounded,
                        color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['full_name'] ?? '',
                        style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Text(p['category'] ?? '',
                        style: TextStyle(fontSize: 12, color: color,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFBBF24), size: 14),
                        const SizedBox(width: 3),
                        Text(
                          rating > 0 ? rating.toStringAsFixed(1) : 'New',
                          style: const TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7D7D7D)),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.location_on_rounded,
                            color: Color(0xFF7D7D7D), size: 12),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(p['city'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12,
                                  color: Color(0xFF7D7D7D),
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Remove heart
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.favorite_rounded,
                      color: Colors.red.shade400, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}