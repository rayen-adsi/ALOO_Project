// lib/screens/provider_setup_screen.dart
// Shown after first login for providers to complete their profile.
// Also accessible from settings/profile for updating.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/user_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import 'edit_profile_screen.dart';
import 'provider_home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Completion % calculator — used on this screen and settings
// ─────────────────────────────────────────────────────────────────────────────
int calcCompletion({
  required bool hasPhoto,
  required bool hasBio,
  required bool hasSkills,
  required bool hasPortfolio,
}) {
  int score = 0;
  if (hasPhoto)     score += 25;
  if (hasBio)       score += 25;
  if (hasSkills)    score += 25;
  if (hasPortfolio) score += 25;
  return score;
}

class ProviderSetupScreen extends StatefulWidget {
  /// If true shows as a standalone "complete profile" flow (after first login).
  /// If false shows as edit mode (from settings).
  final bool isFirstTime;

  const ProviderSetupScreen({super.key, this.isFirstTime = false});

  @override
  State<ProviderSetupScreen> createState() => _ProviderSetupScreenState();
}

class _ProviderSetupScreenState extends State<ProviderSetupScreen> {
  final _picker    = ImagePicker();
  final _skillCtrl = TextEditingController();

  int     _userId      = 0;
  String  _fullName    = '';
  String? _photoPath;
  String? _networkPhoto;
  String  _bio         = '';
  List<String> _skills    = [];
  List<String> _portfolio = []; // URLs or local paths

  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _skillCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = await UserSession.load();
    final userId  = session['id'] ?? 0;
    Map<String, dynamic>? profile;
    try {
      profile = await ApiService.getProviderSettings(userId);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _userId       = userId;
      _fullName     = session['full_name'] ?? '';
      _networkPhoto = profile?['profile_photo'] as String?
          ?? context.read<UserProvider>().photoPath;
      _bio          = profile?['bio'] ?? '';

      // Parse skills JSON array
      final rawSkills = profile?['skills'] as String?;
      if (rawSkills != null && rawSkills.isNotEmpty) {
        try {
          _skills = List<String>.from(jsonDecode(rawSkills));
        } catch (_) {}
      }

      // Parse portfolio JSON array
      final rawPortfolio = profile?['portfolio'] as String?;
      if (rawPortfolio != null && rawPortfolio.isNotEmpty) {
        try {
          _portfolio = List<String>.from(jsonDecode(rawPortfolio));
        } catch (_) {}
      }

      _loading = false;
    });
  }

  int get _completion => calcCompletion(
    hasPhoto:     _photoPath != null || _networkPhoto != null,
    hasBio:       _bio.trim().length >= 10,
    hasSkills:    _skills.isNotEmpty,
    hasPortfolio: _portfolio.isNotEmpty,
  );

  Future<void> _pickProfilePhoto() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 600);
    if (picked != null && mounted) {
      setState(() { _photoPath = picked.path; _networkPhoto = null; });
    }
  }

  Future<void> _pickPortfolioPhoto() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked != null && mounted) {
      setState(() => _portfolio.add(picked.path));
    }
  }

  void _addSkill() {
    final s = _skillCtrl.text.trim();
    if (s.isEmpty) return;
    setState(() { _skills.add(s); _skillCtrl.clear(); });
  }

  void _removeSkill(int i) => setState(() => _skills.removeAt(i));

  void _removePortfolioPhoto(int i) => setState(() => _portfolio.removeAt(i));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // 1. Upload profile photo if new
      if (_photoPath != null) {
        final res = await ApiService.uploadProfilePhoto(
          userId: _userId, role: 'provider', filePath: _photoPath!);
        if (res['success'] == true) {
          _networkPhoto = res['photo_url'];
          _photoPath    = null;
        }
      }

      // 2. Upload new portfolio photos (local paths only)
      final List<String> finalPortfolio = [];
      for (final p in _portfolio) {
        if (p.startsWith('http')) {
          finalPortfolio.add(p); // already uploaded
        } else {
          final res = await ApiService.uploadPortfolioPhoto(
              providerId: _userId, filePath: p);
          if (res['success'] == true && res['photo_url'].isNotEmpty) {
            finalPortfolio.add(res['photo_url'] as String);
          }
        }
      }
      _portfolio = finalPortfolio;

      // 3. Save skills + portfolio to backend
      await ApiService.updateProviderProfile(_userId, {
        'skills':    jsonEncode(_skills),
        'portfolio': jsonEncode(_portfolio),
      });

      // 4. Update UserProvider
      if (mounted) {
        context.read<UserProvider>().update(
          photoPath: _photoPath ?? _networkPhoto,
        );
      }

      if (!mounted) return;
      setState(() => _saving = false);

      if (widget.isFirstTime) {
        // ✅ CHANGED: Navigate to ProviderHomeScreen instead of homeScreen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ProviderHomeScreen()),
          (_) => false,
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final pct  = _completion;

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Stack(
          children: [
            Positioned.fill(child: Image.asset('assets/images/bg.png', fit: BoxFit.cover)),
            Positioned.fill(child: Container(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.80), Colors.white.withOpacity(0.97)]),
            ))),

            if (_loading)
              const Center(child: CircularProgressIndicator(color: Color(0xFF2A5298), strokeWidth: 2.5))
            else
              Column(children: [

                // ── Top bar ────────────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 16, 0),
                    child: Row(children: [
                      if (!widget.isFirstTime)
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF1A3A6B), size: 20)),
                      Expanded(child: Text(
                        widget.isFirstTime
                            ? lang.t('complete_profile')
                            : lang.t('edit_profile'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A3A6B)))),
                      TextButton(
                        onPressed: _saving ? null : _save,
                        child: Text(lang.t('save'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF2A5298)))),
                    ]),
                  ),
                ),

                // ── Content ────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Completion banner ──────────────────────
                        _CompletionCard(pct: pct, lang: lang),
                        const SizedBox(height: 20),

                        // ── Profile photo ──────────────────────────
                        _SectionTitle(title: lang.t('profile_photo'), icon: Icons.camera_alt_rounded, color: const Color(0xFF2A5298)),
                        _PhotoCard(
                          photoPath:    _photoPath ?? _networkPhoto,
                          avatarIndex:  0,
                          fullName:     _fullName,
                          onTap:        _pickProfilePhoto,
                          lang:         lang,
                        ),
                        const SizedBox(height: 20),

                        // ── Skills ─────────────────────────────────
                        _SectionTitle(title: lang.t('skills'), icon: Icons.star_rounded, color: const Color(0xFF7C3AED)),
                        _SkillsCard(
                          skills:   _skills,
                          ctrl:     _skillCtrl,
                          onAdd:    _addSkill,
                          onRemove: _removeSkill,
                          lang:     lang,
                        ),
                        const SizedBox(height: 20),

                        // ── Portfolio ──────────────────────────────
                        _SectionTitle(title: lang.t('portfolio'), icon: Icons.photo_library_rounded, color: const Color(0xFF10B981)),
                        _PortfolioCard(
                          photos:   _portfolio,
                          onAdd:    _pickPortfolioPhoto,
                          onRemove: _removePortfolioPhoto,
                          lang:     lang,
                        ),
                        const SizedBox(height: 28),

                        // ── Save button ────────────────────────────
                        SizedBox(
                          width: double.infinity, height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A3A6B),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(lang.t('save_changes'),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                  ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completion Card
// ─────────────────────────────────────────────────────────────────────────────

class _CompletionCard extends StatelessWidget {
  final int pct;
  final LanguageProvider lang;
  const _CompletionCard({required this.pct, required this.lang});

  Color get _color {
    if (pct == 100) return const Color(0xFF10B981);
    if (pct >= 50)  return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lang.t('profile_completion'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A3A6B))),
            const SizedBox(height: 4),
            Text(pct == 100 ? lang.t('profile_complete_msg') : '$pct% — ${lang.t("complete_profile")}',
                style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w600)),
          ])),
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: _color.withOpacity(0.3), width: 3)),
            child: Center(child: Text('$pct%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _color))),
          ),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value:           pct / 100,
            minHeight:       8,
            backgroundColor: Colors.grey.shade100,
            color:           _color,
          ),
        ),
        const SizedBox(height: 12),
        // Step indicators
        Row(children: [
          _Step(label: lang.t('profile_photo'), done: pct >= 25, color: _color),
          _Step(label: 'Bio',                   done: pct >= 50, color: _color),
          _Step(label: lang.t('skills'),        done: pct >= 75, color: _color),
          _Step(label: lang.t('portfolio'),     done: pct == 100, color: _color),
        ]),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  final String label; final bool done; final Color color;
  const _Step({required this.label, required this.done, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Container(width: 20, height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : Colors.grey.shade200,
          border: Border.all(color: done ? color : Colors.grey.shade300, width: 1.5)),
        child: done ? const Icon(Icons.check_rounded, color: Colors.white, size: 12) : null),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
              color: done ? color : Colors.grey.shade400)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Photo Card
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoCard extends StatelessWidget {
  final String? photoPath, fullName;
  final int     avatarIndex;
  final VoidCallback onTap;
  final LanguageProvider lang;
  const _PhotoCard({this.photoPath, this.fullName, required this.avatarIndex,
      required this.onTap, required this.lang});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))]),
        child: Row(children: [
          Stack(alignment: Alignment.bottomRight, children: [
            UserAvatar(
              avatarIndex: avatarIndex,
              photoPath:   photoPath,
              size:        80,
            ),
            Container(
              width: 26, height: 26,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A5298)),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14)),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(photoPath != null
                    ? '✓ ${lang.t("profile_photo")}'
                    : lang.t('add_photo'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: photoPath != null ? const Color(0xFF10B981) : const Color(0xFF1A3A6B))),
            const SizedBox(height: 4),
            Text(lang.t('tap_to_add'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 16),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skills Card
// ─────────────────────────────────────────────────────────────────────────────

class _SkillsCard extends StatelessWidget {
  final List<String>          skills;
  final TextEditingController ctrl;
  final VoidCallback          onAdd;
  final ValueChanged<int>     onRemove;
  final LanguageProvider      lang;
  const _SkillsCard({required this.skills, required this.ctrl, required this.onAdd,
      required this.onRemove, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Input row
        Row(children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                controller: ctrl,
                onSubmitted: (_) => onAdd(),
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  hintText: lang.t('skill_hint'),
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 24)),
          ),
        ]),

        if (skills.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: skills.asMap().entries.map((e) => _SkillChip(
              label:    e.value,
              onRemove: () => onRemove(e.key),
            )).toList(),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Text(lang.t('add_skills'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String       label;
  final VoidCallback onRemove;
  const _SkillChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF7C3AED).withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED))),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: onRemove,
        child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF7C3AED))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Portfolio Card
// ─────────────────────────────────────────────────────────────────────────────

class _PortfolioCard extends StatelessWidget {
  final List<String>  photos;
  final VoidCallback  onAdd;
  final ValueChanged<int> onRemove;
  final LanguageProvider lang;
  const _PortfolioCard({required this.photos, required this.onAdd,
      required this.onRemove, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Grid of photos + add button
        GridView.builder(
          shrinkWrap: true,
          physics:    const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: photos.length + 1, // +1 for add button
          itemBuilder: (_, i) {
            if (i == photos.length) {
              // Add button
              return GestureDetector(
                onTap: onAdd,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.30), width: 1.5,
                        style: BorderStyle.solid)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: const Color(0xFF10B981).withOpacity(0.7), size: 28),
                    const SizedBox(height: 4),
                    Text(lang.t('add_photo'),
                        style: TextStyle(fontSize: 10, color: const Color(0xFF10B981).withOpacity(0.7),
                            fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                  ]),
                ),
              );
            }
            // Photo tile
            final path = photos[i];
            return Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: path.startsWith('http')
                    ? Image.network(path, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200))
                    : Image.file(File(path), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
              ),
              // Remove button
              Positioned(top: 4, right: 4,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 14)),
                )),
            ]);
          },
        ),

        if (photos.isEmpty) ...[
          const SizedBox(height: 8),
          Text(lang.t('add_portfolio'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Title
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title; final IconData icon; final Color color;
  const _SectionTitle({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 17)),
      const SizedBox(width: 10),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}