// lib/screens/language_select_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import 'app_start.dart';

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Staggered entrance animations
  late final Animation<double>  _bgOpacity;
  late final Animation<double>  _logoOpacity;
  late final Animation<Offset>  _logoSlide;
  late final Animation<double>  _titleOpacity;
  late final Animation<Offset>  _titleSlide;
  late final Animation<double>  _card1Opacity;
  late final Animation<Offset>  _card1Slide;
  late final Animation<double>  _card2Opacity;
  late final Animation<Offset>  _card2Slide;
  late final Animation<double>  _card3Opacity;
  late final Animation<Offset>  _card3Slide;
  late final Animation<double>  _btnOpacity;
  late final Animation<Offset>  _btnSlide;

  String _selected = 'en';

  @override
  void initState() {
    super.initState();

    // Load whatever was previously saved as default selection
    final langProvider = context.read<LanguageProvider>();
    _selected = langProvider.langCode;

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _bgOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.00, 0.30, curve: Curves.easeOut)));

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.10, 0.40, curve: Curves.easeOut)));
    _logoSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.10, 0.45, curve: Curves.easeOutCubic)));

    _titleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.25, 0.55, curve: Curves.easeOut)));
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic)));

    _card1Opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.38, 0.65, curve: Curves.easeOut)));
    _card1Slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.38, 0.68, curve: Curves.easeOutCubic)));

    _card2Opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.48, 0.75, curve: Curves.easeOut)));
    _card2Slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.48, 0.78, curve: Curves.easeOutCubic)));

    _card3Opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.58, 0.85, curve: Curves.easeOut)));
    _card3Slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.58, 0.88, curve: Curves.easeOutCubic)));

    _btnOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.72, 1.00, curve: Curves.easeOut)));
    _btnSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl,
          curve: const Interval(0.72, 1.00, curve: Curves.easeOutCubic)));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final langProvider = context.read<LanguageProvider>();
    await langProvider.setLanguage(_selected);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => const AppStart(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _select(String code) {
    setState(() => _selected = code);
    // Immediately update translations on the screen
    context.read<LanguageProvider>().setLanguage(code);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    const Color primaryBlue = Color(0xFF2A4870);
    const Color lightBlue   = Color(0xFF8CD6E7);

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Stack(
              children: [
                // ── Background ─────────────────────────────────────────
                Opacity(
                  opacity: _bgOpacity.value,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/bg.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          color: primaryBlue.withOpacity(0.28),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                primaryBlue.withOpacity(0.70),
                                lightBlue.withOpacity(0.12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Content ────────────────────────────────────────────
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),

                        // Logo
                        FadeTransition(
                          opacity: _logoOpacity,
                          child: SlideTransition(
                            position: _logoSlide,
                            child: Image.asset(
                              'assets/images/aloo_logo.png',
                              width: 160,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Title + subtitle
                        FadeTransition(
                          opacity: _titleOpacity,
                          child: SlideTransition(
                            position: _titleSlide,
                            child: Column(
                              children: [
                                Text(
                                  lang.t('choose_language'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  lang.t('language_subtitle'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.75),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 38),

                        // Language cards
                        FadeTransition(
                          opacity: _card1Opacity,
                          child: SlideTransition(
                            position: _card1Slide,
                            child: _LangCard(
                              emoji: '🇬🇧',
                              nativeName: 'English',
                              localName: lang.t('lang_english'),
                              selected: _selected == 'en',
                              onTap: () => _select('en'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        FadeTransition(
                          opacity: _card2Opacity,
                          child: SlideTransition(
                            position: _card2Slide,
                            child: _LangCard(
                              emoji: '🇫🇷',
                              nativeName: 'Français',
                              localName: lang.t('lang_french'),
                              selected: _selected == 'fr',
                              onTap: () => _select('fr'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        FadeTransition(
                          opacity: _card3Opacity,
                          child: SlideTransition(
                            position: _card3Slide,
                            child: _LangCard(
                              emoji: '🇹🇳',
                              nativeName: 'العربية',
                              localName: lang.t('lang_arabic'),
                              selected: _selected == 'ar',
                              onTap: () => _select('ar'),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Continue button
                        FadeTransition(
                          opacity: _btnOpacity,
                          child: SlideTransition(
                            position: _btnSlide,
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _onContinue,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0B63F6),
                                  elevation: 8,
                                  shadowColor:
                                      Colors.black.withOpacity(0.28),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  lang.t('continue_btn'),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language Card
// ─────────────────────────────────────────────────────────────────────────────

class _LangCard extends StatefulWidget {
  final String emoji;
  final String nativeName;   // always in that language (e.g. "Français")
  final String localName;    // translated to current UI lang
  final bool selected;
  final VoidCallback onTap;

  const _LangCard({
    required this.emoji,
    required this.nativeName,
    required this.localName,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_LangCard> createState() => _LangCardState();
}

class _LangCardState extends State<_LangCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.white
                : Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFF3B82F6)
                  : Colors.white.withOpacity(0.30),
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Flag + native name column
              Text(widget.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nativeName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: widget.selected
                            ? const Color(0xFF1E40AF)
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.localName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: widget.selected
                            ? const Color(0xFF6B7280)
                            : Colors.white.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              ),
              // Check mark
              AnimatedOpacity(
                opacity: widget.selected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 17),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}