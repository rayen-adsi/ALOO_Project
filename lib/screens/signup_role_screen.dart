// lib/screens/signup_role_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../screens/widgets/lang_toggle_button.dart';
import 'signup_flow_screen.dart';

class SignUpRoleScreen extends StatefulWidget {
  const SignUpRoleScreen({super.key});

  @override
  State<SignUpRoleScreen> createState() => _SignUpRoleScreenState();
}

class _SignUpRoleScreenState extends State<SignUpRoleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double>  _headerOpacity;
  late final Animation<double>  _titleOpacity;
  late final Animation<double>  _card1Opacity;
  late final Animation<double>  _card2Opacity;
  late final Animation<Offset>  _titleSlide;
  late final Animation<Offset>  _card1Slide;
  late final Animation<Offset>  _card2Slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    _headerOpacity = CurvedAnimation(parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut));
    _titleOpacity = CurvedAnimation(parent: _controller,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOut));
    _titleSlide = Tween<Offset>(
        begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic)));
    _card1Opacity = CurvedAnimation(parent: _controller,
        curve: const Interval(0.35, 0.8, curve: Curves.easeOut));
    _card1Slide = Tween<Offset>(
        begin: const Offset(0, 0.18), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic)));
    _card2Opacity = CurvedAnimation(parent: _controller,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOut));
    _card2Slide = Tween<Offset>(
        begin: const Offset(0, 0.18), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic)));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(SignUpRole role) {
    Navigator.push(context,
        MaterialPageRoute(
            builder: (_) => SignUpFlowScreen(initialRole: role)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child:
                  Image.asset('assets/images/bg.png', fit: BoxFit.cover)),

            SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Logo header
                      FadeTransition(
                        opacity: _headerOpacity,
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 18, 20, 8),
                          child: Image.asset(
                              'assets/images/aloo_logo.png',
                              width: 170, fit: BoxFit.contain),
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SlideTransition(
                                position: _titleSlide,
                                child: FadeTransition(
                                  opacity: _titleOpacity,
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 6),
                                      Text(
                                        lang.t('sign_up_to_aloo'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        lang.t('choose_role'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          height: 1.35,
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                    ],
                                  ),
                                ),
                              ),

                              SlideTransition(
                                position: _card1Slide,
                                child: FadeTransition(
                                  opacity: _card1Opacity,
                                  child: _RoleCard(
                                    title: lang.t('role_provider'),
                                    subtitle: lang.t('role_provider_sub'),
                                    leftIcon: const _GradientCircleIcon(
                                      icon: Icons.build_rounded,
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF2BD4FF),
                                          Color(0xFF1E63FF)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    onTap: () =>
                                        _goTo(SignUpRole.provider),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              SlideTransition(
                                position: _card2Slide,
                                child: FadeTransition(
                                  opacity: _card2Opacity,
                                  child: _RoleCard(
                                    title: lang.t('role_client'),
                                    subtitle: lang.t('role_client_sub'),
                                    leftIcon: const _GradientCircleIcon(
                                      icon: Icons.person_rounded,
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF2BD4FF),
                                          Color(0xFF1E63FF)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    onTap: () => _goTo(SignUpRole.client),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 26),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    lang.t('already_have_account'),
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Text(
                                      lang.t('log_in'),
                                      style: const TextStyle(
                                        color: Color(0xFF1E63FF),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Language toggle top-right ──────────────────
                  Positioned(
                    top: 8,
                    right: 12,
                    child: const LangToggleButton(),
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

// ── Role Card ─────────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget leftIcon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.leftIcon,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: const Color(0xFFE5E7EB).withOpacity(0.9),
                width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(_pressed ? 0.10 : 0.06),
                blurRadius: _pressed ? 22 : 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              widget.leftIcon,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827))),
                    const SizedBox(height: 6),
                    Text(widget.subtitle,
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.25,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientCircleIcon extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;

  const _GradientCircleIcon(
      {required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}