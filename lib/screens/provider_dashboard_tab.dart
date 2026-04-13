// lib/screens/provider_dashboard_tab.dart
// Provider's main tab — profile, stats, completion, quick actions, notifications bell.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/notification_provider.dart';
import '../core/user_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import 'edit_profile_screen.dart';
import 'provider_setup_screen.dart';
import 'notifications_screen.dart';
import 'widgets/app_header.dart';

class ProviderDashboardTab extends StatefulWidget {
  final int userId;
  const ProviderDashboardTab({super.key, required this.userId});

  @override
  State<ProviderDashboardTab> createState() => _ProviderDashboardTabState();
}

class _ProviderDashboardTabState extends State<ProviderDashboardTab> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  bool   _loading  = true;
  bool   _isActive = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProviderDashboardTab old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId && widget.userId > 0) _load();
  }

  Future<void> _load() async {
    if (widget.userId == 0) return;
    setState(() => _loading = true);
    try {
      // Load profile and stats in parallel
      final results = await Future.wait([
        ApiService.getProviderSettings(widget.userId),
        ApiService.getProviderStats(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile  = results[0] as Map<String, dynamic>?;
        _stats    = results[1] as Map<String, dynamic>?;
        _isActive = _profile?['is_active'] ?? true;
        _loading  = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(bool value) async {
    setState(() => _isActive = value);
    try {
      await ApiService.updateProviderProfile(widget.userId, {'is_active': value});
    } catch (_) {
      if (mounted) setState(() => _isActive = !value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();

    if (_loading) return const _LoadingState();

    final p            = _profile ?? {};
    final s            = _stats   ?? {};
    final name         = p['full_name']     as String? ?? user.fullName;
    final category     = p['category']      as String? ?? '';
    final city         = p['city']          as String? ?? '';
    final bio          = p['bio']           as String? ?? '';
    final photo        = p['profile_photo'] as String?;
    final rating       = (p['rating']       as num?)?.toDouble() ?? 0.0;
    final totalReviews = (p['total_reviews'] as int?)  ?? 0;
    final isVerified   = p['is_verified']   as bool?   ?? false;
    final completedJobs = (p['completed_jobs'] as int?) ?? 0;
    final score        = (p['score']        as int?)   ?? 0;

    // Parse skills
    List<String> skills = [];
    final rawSkills = p['skills'] as String?;
    if (rawSkills != null && rawSkills.isNotEmpty) {
      try { skills = List<String>.from(jsonDecode(rawSkills)); } catch (_) {}
    }

    // Parse portfolio
    List<String> portfolio = [];
    final rawPortfolio = p['portfolio'] as String?;
    if (rawPortfolio != null && rawPortfolio.isNotEmpty) {
      try { portfolio = List<String>.from(jsonDecode(rawPortfolio)); } catch (_) {}
    }

    final completion = calcCompletion(
      hasPhoto:     photo != null,
      hasBio:       bio.length >= 10,
      hasSkills:    skills.isNotEmpty,
      hasPortfolio: portfolio.isNotEmpty,
    );

    const catToKey = {
      'Plombier':            'cat_plumber',
      'Électricien':         'cat_electrician',
      'Mécanicien':          'cat_mechanic',
      'Femme de ménage':     'cat_cleaner',
      'Professeur':          'cat_tutor',
      'Développeur':         'cat_developer',
      'Réparation domicile': 'cat_home_repair',
    };
    final catLabel = lang.t(catToKey[category] ?? category);

    // Stats from the /stats endpoint
    final tierLabel  = s['tier_label']  as String? ?? '';
    final tierColor  = _parseHex(s['tier_color'] as String? ?? '#94A3B8');
    final jobsToNext = (s['jobs_to_next'] as int?) ?? 5;
    final nextMilestone = (s['next_jobs_milestone'] as int?) ?? 5;

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
            child: RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF2A5298),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Header row: logo + bell + availability ────
                    Row(children: [
                      Image.asset('assets/images/aloo_logo.png', height: 50, fit: BoxFit.contain),
                      const Spacer(),

                      // 🔔 Notification bell
                     Consumer<NotificationProvider>(
  builder: (_, notifs, __) =>
    NotifBellWidget(unreadCount: notifs.unreadCount),
),
                      const SizedBox(width: 10),

                      _AvailabilityToggle(
                        isActive:  _isActive,
                        lang:      lang,
                        onChanged: _toggleActive,
                      ),
                    ]),

                    const SizedBox(height: 8),

                    // ── Welcome ───────────────────────────────────
                    Text(lang.t('welcome_back'),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                    Text(name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A3A6B))),

                    const SizedBox(height: 16),

                    // ── Score / Tier card ─────────────────────────
                    if (tierLabel.isNotEmpty)
                      _ScoreCard(
                        score:       score,
                        tierLabel:   tierLabel,
                        tierColor:   tierColor,
                        completedJobs: completedJobs,
                        jobsToNext:  jobsToNext,
                        nextMilestone: nextMilestone,
                        lang:        lang,
                      ),

                    if (tierLabel.isNotEmpty) const SizedBox(height: 16),

                    // ── Profile card ──────────────────────────────
                    _ProfileCard(
                      name:       name,
                      category:   catLabel,
                      city:       city,
                      photo:      photo ?? user.photoPath,
                      avatarIdx:  user.avatarIndex,
                      rating:     rating,
                      reviews:    totalReviews,
                      isVerified: isVerified,
                      isActive:   _isActive,
                      lang:       lang,
                      onEdit: () async {
                        final updated = await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                        if (updated == true && mounted) {
                          await context.read<UserProvider>().load();
                          _load();
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Completion banner ─────────────────────────
                    if (completion < 100)
                      _CompletionBanner(pct: completion, lang: lang, onTap: () async {
                        final updated = await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ProviderSetupScreen()));
                        if (updated == true && mounted) _load();
                      }),

                    if (completion < 100) const SizedBox(height: 16),

                    // ── Stats row ─────────────────────────────────
                    _StatsRow(
                      rating:  rating,
                      reviews: totalReviews,
                      skills:  skills.length,
                      photos:  portfolio.length,
                      lang:    lang,
                    ),

                    const SizedBox(height: 16),

                    // ── Completed jobs stat ───────────────────────
                    _JobsStatCard(
                      completedJobs: completedJobs,
                      jobsToNext:    jobsToNext,
                      nextMilestone: nextMilestone,
                      lang:          lang,
                    ),

                    const SizedBox(height: 20),

                    // ── Quick actions ─────────────────────────────
                    Text(lang.t('quick_actions').toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                          color: Colors.grey.shade500, letterSpacing: 1.2)),
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(child: _QuickAction(
                        icon: Icons.edit_rounded, label: lang.t('edit_profile'),
                        color: const Color(0xFF2A5298),
                        onTap: () async {
                          final updated = await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                          if (updated == true && mounted) {
                            await context.read<UserProvider>().load();
                            _load();
                          }
                        },
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _QuickAction(
                        icon: Icons.photo_library_rounded, label: lang.t('portfolio'),
                        color: const Color(0xFF10B981),
                        onTap: () async {
                          final updated = await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ProviderSetupScreen()));
                          if (updated == true && mounted) _load();
                        },
                      )),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _QuickAction(
                        icon: Icons.star_rounded, label: lang.t('skills'),
                        color: const Color(0xFF7C3AED),
                        onTap: () async {
                          final updated = await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ProviderSetupScreen()));
                          if (updated == true && mounted) _load();
                        },
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _QuickAction(
                        icon: Icons.notifications_rounded,
                        label: lang.t('notifications'),
                        color: const Color(0xFFF59E0B),
                        onTap: () async {
                          await Navigator.push(context, PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const NotificationsScreen(),
                            transitionDuration: const Duration(milliseconds: 320),
                            transitionsBuilder: (_, anim, __, child) => FadeTransition(
                              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                              child: child)));
                        },
                      )),
                    ]),

                    const SizedBox(height: 24),

                    // ── Recent reviews ────────────────────────────
                    _RecentReviewsSection(providerId: widget.userId, lang: lang),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseHex(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF94A3B8);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION BELL — same as home_screen version
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
      setState(() => _unread = notifs.where((n) => n['is_read'] == false).length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => const NotificationsScreen(),
          transitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child)));
        _load();
      },
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color:  Colors.white.withOpacity(0.18),
            shape:  BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.30), width: 1)),
          child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20)),
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
// SCORE CARD — tier + progress to next milestone
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final int    score;
  final String tierLabel;
  final Color  tierColor;
  final int    completedJobs;
  final int    jobsToNext;
  final int    nextMilestone;
  final LanguageProvider lang;

  const _ScoreCard({
    required this.score,
    required this.tierLabel,
    required this.tierColor,
    required this.completedJobs,
    required this.jobsToNext,
    required this.nextMilestone,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [tierColor.withOpacity(0.85), tierColor]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: tierColor.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [

        // Score circle
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.20),
            border: Border.all(color: Colors.white.withOpacity(0.50), width: 2)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$score', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            Text('pts', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.8))),
          ]),
        ),
        const SizedBox(width: 14),

        // Tier info + progress
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(tierLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8)),
              child: Text('$completedJobs jobs',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
          ]),
          const SizedBox(height: 6),
          Text('$jobsToNext more jobs to reach $nextMilestone',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.85))),
          const SizedBox(height: 8),
          // Progress bar toward next milestone
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: nextMilestone > 0 ? completedJobs / nextMilestone : 0.0,
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.25),
              color: Colors.white,
            ),
          ),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOBS STAT CARD — shows completed jobs with motivational message
// ─────────────────────────────────────────────────────────────────────────────

class _JobsStatCard extends StatelessWidget {
  final int completedJobs;
  final int jobsToNext;
  final int nextMilestone;
  final LanguageProvider lang;

  const _JobsStatCard({
    required this.completedJobs,
    required this.jobsToNext,
    required this.nextMilestone,
    required this.lang,
  });

  String _motivationalMessage() {
    if (completedJobs == 0) return 'Complete your first job to start earning points! 🚀';
    if (completedJobs == 1) return 'Great start! First job done 🎉';
    if (completedJobs < 5)  return 'You\'re on a roll! Keep going 💪';
    if (completedJobs < 10) return 'Excellent work! Clients love you ⭐';
    return 'You\'re a top performer on ALOO! 🏆';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Row(children: [

        // Big number
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.10),
            borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$completedJobs', style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
          ]),
        ),
        const SizedBox(width: 14),

        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Completed Jobs',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A3A6B))),
          const SizedBox(height: 3),
          Text(_motivationalMessage(),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8)),
              child: Text('Next milestone: $nextMilestone jobs',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981)))),
          ]),
        ])),

        // Checkmark icon
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.10),
            shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVAILABILITY TOGGLE
// ─────────────────────────────────────────────────────────────────────────────

class _AvailabilityToggle extends StatelessWidget {
  final bool             isActive;
  final LanguageProvider lang;
  final ValueChanged<bool> onChanged;

  const _AvailabilityToggle({
    required this.isActive,
    required this.lang,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isActive),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF10B981).withOpacity(0.12)
              : Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF10B981).withOpacity(0.4)
                : Colors.red.withOpacity(0.3),
            width: 1.2)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(duration: const Duration(milliseconds: 250),
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFF10B981) : Colors.red.shade400)),
          const SizedBox(width: 6),
          Text(isActive ? lang.t('available') : lang.t('unavailable'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: isActive ? const Color(0xFF10B981) : Colors.red.shade400)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final String  name, category, city;
  final String? photo;
  final int     avatarIdx, reviews;
  final double  rating;
  final bool    isVerified, isActive;
  final LanguageProvider lang;
  final VoidCallback     onEdit;

  const _ProfileCard({
    required this.name,
    required this.category,
    required this.city,
    required this.photo,
    required this.avatarIdx,
    required this.rating,
    required this.reviews,
    required this.isVerified,
    required this.isActive,
    required this.lang,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))]),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(width: 80, height: 80,
            child: photo != null && photo!.isNotEmpty
                ? Image.network(photo!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => UserAvatar(avatarIndex: avatarIdx, size: 80))
                : UserAvatar(avatarIndex: avatarIdx, size: 80)),
        ),
        const SizedBox(width: 14),

        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(name, style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1A3A6B)),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (isVerified)
              const Padding(padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.verified_rounded, color: Color(0xFF2A5298), size: 18)),
          ]),
          const SizedBox(height: 3),
          Text(category, style: TextStyle(
            fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
            const SizedBox(width: 3),
            Text(rating > 0 ? rating.toStringAsFixed(1) : 'New',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            if (reviews > 0)
              Text('  ($reviews)', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            const SizedBox(width: 10),
            Icon(Icons.location_on_rounded, color: Colors.grey.shade400, size: 14),
            const SizedBox(width: 2),
            Text(city, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ]),
        ])),

        GestureDetector(
          onTap: onEdit,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF2A5298).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.edit_rounded, color: Color(0xFF2A5298), size: 18))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLETION BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _CompletionBanner extends StatelessWidget {
  final int              pct;
  final LanguageProvider lang;
  final VoidCallback     onTap;

  const _CompletionBanner({required this.pct, required this.lang, required this.onTap});

  Color get _color {
    if (pct >= 75) return const Color(0xFF10B981);
    if (pct >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _color.withOpacity(0.25), width: 1)),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: _color.withOpacity(0.4), width: 2.5)),
            child: Center(child: Text('$pct%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _color)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lang.t('complete_profile'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _color)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100, minHeight: 5,
                backgroundColor: _color.withOpacity(0.15),
                color: _color)),
          ])),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, color: _color.withOpacity(0.6), size: 14),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final double           rating;
  final int              reviews, skills, photos;
  final LanguageProvider lang;

  const _StatsRow({
    required this.rating, required this.reviews,
    required this.skills, required this.photos, required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatTile(icon: Icons.star_rounded,          color: const Color(0xFFFBBF24),
        value: rating > 0 ? rating.toStringAsFixed(1) : '—', label: lang.t('rating')),
      const SizedBox(width: 10),
      _StatTile(icon: Icons.rate_review_rounded,   color: const Color(0xFF2A5298),
        value: '$reviews', label: lang.t('reviews')),
      const SizedBox(width: 10),
      _StatTile(icon: Icons.auto_awesome_rounded,  color: const Color(0xFF7C3AED),
        value: '$skills',  label: lang.t('skills')),
      const SizedBox(width: 10),
      _StatTile(icon: Icons.photo_library_rounded, color: const Color(0xFF10B981),
        value: '$photos',  label: lang.t('portfolio')),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon; final Color color; final String value, label;
  const _StatTile({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))]),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1A3A6B))),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTION
// ─────────────────────────────────────────────────────────────────────────────

class _QuickAction extends StatefulWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  @override State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:       widget.onTap,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0, duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))]),
          child: Column(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: widget.color.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
              child: Icon(widget.icon, color: widget.color, size: 22)),
            const SizedBox(height: 8),
            Text(widget.label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.color),
              textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT REVIEWS
// ─────────────────────────────────────────────────────────────────────────────

class _RecentReviewsSection extends StatefulWidget {
  final int providerId; final LanguageProvider lang;
  const _RecentReviewsSection({required this.providerId, required this.lang});
  @override State<_RecentReviewsSection> createState() => _RecentReviewsSectionState();
}

class _RecentReviewsSectionState extends State<_RecentReviewsSection> {
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (widget.providerId == 0) return;
    try {
      final data = await ApiService.getReviews(widget.providerId);
      if (!mounted) return;
      setState(() => _reviews = data.take(3).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(lang.t('reviews').toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
            color: Colors.grey.shade500, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      if (_reviews.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(children: [
            Icon(Icons.rate_review_outlined, color: Colors.grey.shade300, size: 40),
            const SizedBox(height: 8),
            Text(lang.t('no_reviews'), style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          ]))
      else
        ..._reviews.map((r) => _MiniReviewTile(review: r)),
    ]);
  }
}

class _MiniReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  const _MiniReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final name    = review['client_name'] as String? ?? 'Unknown';
    final rating  = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = review['comment'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 38, height: 38,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A5298)),
          child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            const SizedBox(width: 8),
            ...List.generate(5, (i) => Icon(
              i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(0xFFFBBF24), size: 12)),
          ]),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(comment, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4)),
          ],
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING STATE
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFFF5F7FA),
    body: Center(child: CircularProgressIndicator(color: Color(0xFF2A5298), strokeWidth: 2.5)));
}