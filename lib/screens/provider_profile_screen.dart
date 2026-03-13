// lib/screens/provider_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import 'chat_screen.dart';

class ProviderProfileScreen extends StatefulWidget {
  final int providerId;
  const ProviderProfileScreen({super.key, required this.providerId});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  Map<String, dynamic>? _provider;
  bool   _loading   = true;
  String? _error;

  bool _isFavorite  = false;
  int  _clientId    = 0;
  String _userRole  = 'client';

  // Review form
  double _selectedRating = 0;
  final  _commentCtrl    = TextEditingController();
  bool   _submittingReview = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final session = await UserSession.load();
    _clientId = session['id']   ?? 0;
    _userRole = session['role'] ?? 'client';

    await _loadProvider();

    if (_userRole == 'client' && _clientId > 0) {
      final fav = await ApiService.checkFavorite(
          clientId: _clientId, providerId: widget.providerId);
      if (mounted) setState(() => _isFavorite = fav);
    }
  }

  Future<void> _loadProvider() async {
    setState(() { _loading = true; _error = null; });
    final data = await ApiService.getProviderProfile(widget.providerId);
    if (!mounted) return;
    if (data == null) {
      setState(() { _error = 'Could not load profile'; _loading = false; });
    } else {
      setState(() { _provider = data; _loading = false; });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_userRole != 'client' || _clientId == 0) return;
    setState(() => _isFavorite = !_isFavorite);
    if (_isFavorite) {
      await ApiService.addFavorite(clientId: _clientId, providerId: widget.providerId);
    } else {
      await ApiService.removeFavorite(clientId: _clientId, providerId: widget.providerId);
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a rating')));
      return;
    }
    setState(() => _submittingReview = true);
    final result = await ApiService.addReview(
      providerId: widget.providerId,
      clientId:   _clientId,
      rating:     _selectedRating,
      comment:    _commentCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submittingReview = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result['message'] ?? '')));
    if (result['success'] == true) {
      _commentCtrl.clear();
      setState(() => _selectedRating = 0);
      _loadProvider(); // refresh rating
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2A5298)))
            : _error != null
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.grey.shade400, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _loadProvider, child: const Text('Retry')),
                    ],
                  ))
                : _buildContent(lang),
      ),
    );
  }

  Widget _buildContent(LanguageProvider lang) {
    final p           = _provider!;
    final color       = _categoryColors[p['category'] as String? ?? ''] ?? const Color(0xFF1A6B9A);
    final double rating = (p['rating'] as num?)?.toDouble() ?? 0.0;
    final reviews     = List<Map<String, dynamic>>.from(p['reviews'] ?? []);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── App Bar ──────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: color,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          actions: [
            if (_userRole == 'client')
              GestureDetector(
                onTap: _toggleFavorite,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFavorite ? Colors.red.shade300 : Colors.white,
                    ),
                  ),
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.85), color],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Avatar
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                    ),
                    child: p['profile_photo'] != null
                        ? ClipOval(child: Image.network(p['profile_photo'], fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded,
                                color: Colors.white, size: 48)))
                        : const Icon(Icons.person_rounded, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 10),
                  Text(p['full_name'] ?? '',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(p['category'] ?? '',
                            style: const TextStyle(fontSize: 12, color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (p['is_verified'] == true) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, color: Colors.white, size: 11),
                              SizedBox(width: 3),
                              Text('Verified', style: TextStyle(fontSize: 11,
                                  color: Colors.white, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Stats row ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                        blurRadius: 12, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    children: [
                      _StatItem(label: 'Rating',
                          value: rating > 0 ? rating.toStringAsFixed(1) : 'New',
                          icon: Icons.star_rounded, iconColor: const Color(0xFFFBBF24)),
                      _VertDivider(),
                      _StatItem(label: 'Reviews',
                          value: '${p['total_reviews'] ?? 0}',
                          icon: Icons.rate_review_outlined, iconColor: const Color(0xFF2A5298)),
                      _VertDivider(),
                      _StatItem(label: 'City',
                          value: p['city'] ?? '—',
                          icon: Icons.location_on_rounded, iconColor: const Color(0xFF10B981)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── About ────────────────────────────────────────────────
                _SectionHeader(title: 'About'),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                        blurRadius: 12, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoLine(icon: Icons.phone_rounded,
                          color: const Color(0xFF10B981), text: p['phone'] ?? '—'),
                      const SizedBox(height: 8),
                      _InfoLine(icon: Icons.location_city_rounded,
                          color: const Color(0xFF2A5298), text: p['address'] ?? '—'),
                      const SizedBox(height: 12),
                      Text(p['bio'] ?? '',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700,
                              height: 1.5)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Contact button ────────────────────────────────────────
                if (_userRole == 'client')
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2174FC),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            providerId:       widget.providerId,
                            providerName:     p['full_name'] ?? '',
                            providerCategory: p['category'],
                          ),
                        ));
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          color: Colors.white, size: 20),
                      label: const Text('Contact Provider',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),

                const SizedBox(height: 24),

                // ── Reviews ──────────────────────────────────────────────
                _SectionHeader(title: 'Reviews (${reviews.length})'),
                const SizedBox(height: 10),

                if (reviews.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(children: [
                      Icon(Icons.reviews_outlined, color: Colors.grey.shade300, size: 40),
                      const SizedBox(height: 8),
                      Text('No reviews yet', style: TextStyle(color: Colors.grey.shade400)),
                    ]),
                  )
                else
                  ...reviews.map((r) => _ReviewCard(review: r)),

                // ── Leave a review ────────────────────────────────────────
                if (_userRole == 'client') ...[
                  const SizedBox(height: 20),
                  _SectionHeader(title: 'Leave a Review'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                          blurRadius: 12, offset: const Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Star picker
                        Row(
                          children: List.generate(5, (i) => GestureDetector(
                            onTap: () => setState(() => _selectedRating = i + 1.0),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                i < _selectedRating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: const Color(0xFFFBBF24),
                                size: 32,
                              ),
                            ),
                          )),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _commentCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Write a comment (optional)',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: const Color(0xFFF3F4F6),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A3A6B),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _submittingReview ? null : _submitReview,
                            child: _submittingReview
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Submit Review',
                                    style: TextStyle(fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const Map<String, Color> _categoryColors = {
    'Plombier':            Color(0xFF1A6B9A),
    'Électricien':         Color(0xFFF59E0B),
    'Mécanicien':          Color(0xFF64748B),
    'Femme de ménage':     Color(0xFFEC4899),
    'Professeur':          Color(0xFF10B981),
    'Développeur':         Color(0xFF8B5CF6),
    'Réparation domicile': Color(0xFF4A3580),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF1A3A6B), Color(0xFF2A5298)],
              ),
              borderRadius: BorderRadius.circular(4),
            )),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A))),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color iconColor;
  const _StatItem({required this.label, required this.value,
      required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15,
              fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: Colors.grey.shade100);
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoLine({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w500, color: Color(0xFF374151)))),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final double rating = (review['rating'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2A5298).withOpacity(0.1),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Color(0xFF2A5298), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review['client_name'] ?? 'Anonymous',
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: const Color(0xFFFBBF24), size: 14,
                      )),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review['comment'] != null && (review['comment'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review['comment'],
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
          ],
        ],
      ),
    );
  }
}