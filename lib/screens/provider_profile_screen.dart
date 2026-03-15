// lib/screens/provider_profile_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';

class ProviderProfileScreen extends StatefulWidget {
  final int providerId;
  const ProviderProfileScreen({super.key, required this.providerId});
  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  Map<String, dynamic>? _provider;
  bool   _loading    = true;
  bool   _isFavorite = false;
  bool   _favLoading = false;
  String _userRole   = 'client';
  int    _userId     = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final session = await UserSession.load();
    _userRole = session['role'] ?? 'client';
    _userId   = session['id']   ?? 0;

    final data = await ApiService.getProviderProfile(widget.providerId);
    bool isFav = false;
    if (_userRole == 'client' && _userId > 0) {
      isFav = await ApiService.checkFavorite(
          clientId: _userId, providerId: widget.providerId);
    }
    if (!mounted) return;
    setState(() {
      _provider  = data;
      _isFavorite = isFav;
      _loading   = false;
    });
  }

  Future<void> _toggleFavorite() async {
    if (_userRole != 'client') return;
    setState(() => _favLoading = true);
    try {
      if (_isFavorite) {
        await ApiService.removeFavorite(
            clientId: _userId, providerId: widget.providerId);
      } else {
        await ApiService.addFavorite(
            clientId: _userId, providerId: widget.providerId);
      }
      if (!mounted) return;
      setState(() { _isFavorite = !_isFavorite; _favLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator(
            color: Color(0xFF2A5298), strokeWidth: 2.5)),
      );
    }
    if (_provider == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
            leading: const BackButton(color: Color(0xFF1A3A6B))),
        body: const Center(child: Text('Provider not found')),
      );
    }

    final p            = _provider!;
    final name         = p['full_name']     as String? ?? '';
    final category     = p['category']      as String? ?? '';
    final city         = p['city']          as String? ?? '';
    final bio          = p['bio']           as String? ?? '';
    final photo        = p['profile_photo'] as String?;
    final rating       = (p['rating']       as num?)?.toDouble() ?? 0.0;
    final totalReviews = (p['total_reviews'] as int?)  ?? 0;
    final isVerified   = p['is_verified']   as bool?   ?? false;
    final reviews      = (p['reviews']      as List?)
        ?.cast<Map<String, dynamic>>() ?? [];

    List<String> skills = [];
    final rawSkills = p['skills'] as String?;
    if (rawSkills != null && rawSkills.isNotEmpty) {
      try { skills = List<String>.from(jsonDecode(rawSkills)); } catch (_) {}
    }

    List<String> portfolio = [];
    final rawPortfolio = p['portfolio'] as String?;
    if (rawPortfolio != null && rawPortfolio.isNotEmpty) {
      try { portfolio = List<String>.from(jsonDecode(rawPortfolio)); } catch (_) {}
    }

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Stack(
          children: [
            // Standard background
            Positioned.fill(
              child: Image.asset('assets/images/bg.png', fit: BoxFit.cover)),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.80),
                      Colors.white.withOpacity(0.97),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // ── Top bar ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
                    child: Row(
                      children: [
                        // Back button
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF1A3A6B), size: 20)),

                        const Spacer(),

                        // Favorite heart — only for clients
                        if (_userRole == 'client')
                          _favLoading
                              ? const SizedBox(
                                  width: 40, height: 40,
                                  child: Center(child: SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF2A5298),
                                        strokeWidth: 2))))
                              : GestureDetector(
                                  onTap: _toggleFavorite,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: _isFavorite
                                          ? const Color(0xFFFF4D6D)
                                              .withOpacity(0.12)
                                          : Colors.white.withOpacity(0.85),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _isFavorite
                                            ? const Color(0xFFFF4D6D)
                                            : Colors.grey.shade200,
                                        width: 1.5,
                                      ),
                                      boxShadow: [BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2))],
                                    ),
                                    child: Icon(
                                      _isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: _isFavorite
                                          ? const Color(0xFFFF4D6D)
                                          : Colors.grey.shade400,
                                      size: 20,
                                    ),
                                  ),
                                ),
                      ],
                    ),
                  ),

                  // ── Scrollable content ───────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ── Provider info ─────────────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Photo
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: photo != null
                                    ? Image.network(photo,
                                        width: 110, height: 130,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _InitialBox(name: name,
                                                w: 110, h: 130))
                                    : _InitialBox(name: name,
                                        w: 110, h: 130),
                              ),
                              const SizedBox(width: 16),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Expanded(
                                        child: Text(name,
                                          style: const TextStyle(
                                            fontSize:   20,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF1A3A6B)))),
                                      if (isVerified)
                                        const Icon(Icons.verified_rounded,
                                            color: Color(0xFF2A5298),
                                            size: 18),
                                    ]),
                                    const SizedBox(height: 3),
                                    Text(category,
                                      style: TextStyle(
                                        fontSize:   14,
                                        color:      Colors.grey.shade500,
                                        fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      ...List.generate(5, (i) => Icon(
                                        i < rating.round()
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        color: const Color(0xFFFBBF24),
                                        size: 16)),
                                      const SizedBox(width: 5),
                                      Text(
                                        rating > 0
                                            ? rating.toStringAsFixed(1)
                                            : 'New',
                                        style: const TextStyle(
                                          fontSize:   14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B))),
                                      if (totalReviews > 0)
                                        Text('  ($totalReviews)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400)),
                                    ]),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      const Icon(Icons.location_on_rounded,
                                          color: Color(0xFF2A5298),
                                          size: 14),
                                      const SizedBox(width: 3),
                                      Text(city,
                                        style: const TextStyle(
                                          fontSize:   13,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500)),
                                    ]),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── Contact button ─────────────────────────
                          if (_userRole == 'client')
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2A5298),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14))),
                                icon: const Icon(Icons.chat_bubble_rounded,
                                    color: Colors.white, size: 18),
                                label: Text(lang.t('contact'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                                onPressed: () => Navigator.push(context,
                                  chatScreenRoute(
                                    providerId:       widget.providerId,
                                    providerName:     name,
                                    providerCategory: category,
                                    providerCity:     city,
                                  )),
                              ),
                            ),

                          if (_userRole == 'client')
                            const SizedBox(height: 24),

                          // ── Bio ────────────────────────────────────
                          if (bio.isNotEmpty) ...[
                            _SectionTitle(title: 'Bio'),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))]),
                              child: Text(bio,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF475569),
                                  height: 1.6,
                                  fontWeight: FontWeight.w400))),
                            const SizedBox(height: 24),
                          ],

                          // ── Compétences ────────────────────────────
                          if (skills.isNotEmpty) ...[
                            _SectionTitle(
                                title: '${lang.t('skills')}:'),
                            const SizedBox(height: 10),
                            ...skills.map((s) => _SkillRow(label: s)),
                            const SizedBox(height: 24),
                          ],

                          // ── Galerie ────────────────────────────────
                          if (portfolio.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                _SectionTitle(title: lang.t('portfolio')),
                                if (portfolio.length > 3)
                                  GestureDetector(
                                    onTap: () => _showAllPhotos(
                                        context, portfolio, name),
                                    child: Row(children: [
                                      Text(lang.t('view_all'),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2A5298))),
                                      const Icon(
                                          Icons.chevron_right_rounded,
                                          color: Color(0xFF2A5298),
                                          size: 18),
                                    ])),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: List.generate(
                                portfolio.length > 3
                                    ? 3 : portfolio.length,
                                (i) => Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        _showPhoto(context, portfolio[i]),
                                    child: Container(
                                      height: 100,
                                      margin: EdgeInsets.only(
                                          right: i < 2 ? 8 : 0),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: _PortfolioImage(
                                            path: portfolio[i]))),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // ── Commentaires ───────────────────────────
                          _SectionTitle(
                              title: '${lang.t('reviews')}:'),
                          const SizedBox(height: 10),

                          if (reviews.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))]),
                              child: Column(children: [
                                Icon(Icons.rate_review_outlined,
                                    color: Colors.grey.shade300,
                                    size: 40),
                                const SizedBox(height: 8),
                                Text(lang.t('no_reviews'),
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14)),
                              ]))
                          else
                            ...reviews.map(
                                (r) => _ReviewTile(review: r)),
                        ],
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

  void _showPhoto(BuildContext ctx, String url) => Navigator.push(ctx,
      MaterialPageRoute(builder: (_) => _PhotoViewer(url: url)));

  void _showAllPhotos(
      BuildContext ctx, List<String> photos, String name) =>
      Navigator.push(ctx, MaterialPageRoute(
          builder: (_) =>
              _AllPhotosScreen(photos: photos, providerName: name)));
}

// ─────────────────────────────────────────────────────────────────────────────
// Skill row — blue pill chip
// ─────────────────────────────────────────────────────────────────────────────

class _SkillRow extends StatelessWidget {
  final String label;
  const _SkillRow({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A5298).withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
            color: const Color(0xFF2A5298).withOpacity(0.20), width: 1)),
      child: Row(children: [
        Container(width: 6, height: 6,
          decoration: const BoxDecoration(
              color: Color(0xFF2A5298), shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(label,
          style: const TextStyle(
            fontSize:   13.5,
            fontWeight: FontWeight.w600,
            color:      Color(0xFF1A3A6B)))),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Review tile
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewTile({required this.review});

  String _fmt(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final name    = review['client_name']  as String? ?? 'Unknown';
    final photo   = review['client_photo'] as String?;
    final rating  = (review['rating']      as num?)?.toDouble() ?? 0.0;
    final comment = review['comment']      as String? ?? '';
    final date    = _fmt(review['created_at'] as String?);

    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color:      Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset:     const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ClipOval(
              child: photo != null
                  ? Image.network(photo, width: 42, height: 42,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _InitialCircle(name: name, size: 42))
                  : _InitialCircle(name: name, size: 42)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
                const SizedBox(height: 3),
                Row(children: List.generate(5, (i) => Icon(
                  i < rating.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFFBBF24), size: 14))),
              ])),
            Text(date, style: TextStyle(
                fontSize: 12, color: Colors.grey.shade400,
                fontWeight: FontWeight.w500)),
          ]),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment, style: const TextStyle(
                fontSize: 13.5, color: Color(0xFF475569),
                height: 1.55, fontWeight: FontWeight.w400)),
          ],
        ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section title
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Text(title,
    style: const TextStyle(
      fontSize:   18,
      fontWeight: FontWeight.w900,
      color:      Color(0xFF1A2E4A)));
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallbacks
// ─────────────────────────────────────────────────────────────────────────────

class _InitialBox extends StatelessWidget {
  final String name; final double w, h;
  const _InitialBox(
      {required this.name, required this.w, required this.h});

  @override
  Widget build(BuildContext context) => Container(
    width: w, height: h, color: const Color(0xFF2A5298),
    child: Center(child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(fontSize: w * 0.28,
          fontWeight: FontWeight.w900, color: Colors.white))));
}

class _InitialCircle extends StatelessWidget {
  final String name; final double size;
  const _InitialCircle({required this.name, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size, color: const Color(0xFF2A5298),
    child: Center(child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(fontSize: size * 0.38,
          fontWeight: FontWeight.w800, color: Colors.white))));
}

// ─────────────────────────────────────────────────────────────────────────────
// Portfolio image
// ─────────────────────────────────────────────────────────────────────────────

class _PortfolioImage extends StatelessWidget {
  final String path;
  const _PortfolioImage({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade200,
          child: Icon(Icons.broken_image_rounded,
              color: Colors.grey.shade400)));
    }
    return Image.file(File(path), fit: BoxFit.cover);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo viewer
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoViewer extends StatelessWidget {
  final String url;
  const _PhotoViewer({required this.url});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(children: [
      Center(child: InteractiveViewer(
        child: url.startsWith('http')
            ? Image.network(url, fit: BoxFit.contain)
            : Image.file(File(url), fit: BoxFit.contain))),
      SafeArea(child: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton(
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 20)),
          onPressed: () => Navigator.pop(context)))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// All photos grid
// ─────────────────────────────────────────────────────────────────────────────

class _AllPhotosScreen extends StatelessWidget {
  final List<String> photos;
  final String       providerName;
  const _AllPhotosScreen(
      {required this.photos, required this.providerName});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0F172A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0F172A),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context)),
      title: Text(providerName,
        style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.w700, fontSize: 16))),
    body: GridView.builder(
      padding:  const EdgeInsets.all(8),
      physics:  const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: photos.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => _PhotoViewer(url: photos[i]))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: _PortfolioImage(path: photos[i])))),
  );
}