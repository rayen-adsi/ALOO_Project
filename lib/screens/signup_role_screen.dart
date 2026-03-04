import 'package:flutter/material.dart';
import 'signup_flow_screen.dart'; // contains SignUpFlowScreen + SignUpRole

class SignUpRoleScreen extends StatefulWidget {
  const SignUpRoleScreen({super.key});

  @override
  State<SignUpRoleScreen> createState() => _SignUpRoleScreenState();
}

class _SignUpRoleScreenState extends State<SignUpRoleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _headerOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _card1Opacity;
  late final Animation<double> _card2Opacity;

  late final Animation<Offset> _titleSlide;
  late final Animation<Offset> _card1Slide;
  late final Animation<Offset> _card2Slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );

    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _card1Opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
    );

    _card1Slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _card2Opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );

    _card2Slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );

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

  // ✅ NORMAL navigation (no PageRouteBuilder)
  void _goToProviderSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SignUpFlowScreen(initialRole: SignUpRole.provider),
      ),
    );
  }

  void _goToClientSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SignUpFlowScreen(initialRole: SignUpRole.client),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                FadeTransition(
                  opacity: _headerOpacity,
                  child: const _Header(),
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
                            child: const Column(
                              children: [
                                SizedBox(height: 6),
                                Text(
                                  "Sign up to ALOO",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Choose your role to create an account:",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.35,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 18),
                              ],
                            ),
                          ),
                        ),

                        SlideTransition(
                          position: _card1Slide,
                          child: FadeTransition(
                            opacity: _card1Opacity,
                            child: _RoleCard(
                              title: "Service Provider",
                              subtitle: "Offer your services and\ngrow your business.",
                              leftIcon: const _GradientCircleIcon(
                                icon: Icons.build_rounded,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF2BD4FF), Color(0xFF1E63FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              onTap: _goToProviderSignUp,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        SlideTransition(
                          position: _card2Slide,
                          child: FadeTransition(
                            opacity: _card2Opacity,
                            child: _RoleCard(
                              title: "Client",
                              subtitle: "Find and hire local service\nprofessionals.",
                              leftIcon: const _GradientCircleIcon(
                                icon: Icons.person_rounded,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF2BD4FF), Color(0xFF1E63FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              onTap: _goToClientSignUp,
                            ),
                          ),
                        ),

                        const SizedBox(height: 26),

                        _BottomLogin(onTapLogin: () => Navigator.pop(context)),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Image.asset(
        "assets/images/aloo_logo.png",
        width: 170,
        fit: BoxFit.contain,
      ),
    );
  }
}

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

  void _down(_) => setState(() => _pressed = true);
  void _up(_) => setState(() => _pressed = false);
  void _cancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE5E7EB).withOpacity(0.9),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_pressed ? 0.10 : 0.06),
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
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.25,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

  const _GradientCircleIcon({
    required this.icon,
    required this.gradient,
  });

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
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _BottomLogin extends StatelessWidget {
  final VoidCallback onTapLogin;
  const _BottomLogin({required this.onTapLogin});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Already have an account? ",
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w700,
          ),
        ),
        GestureDetector(
          onTap: onTapLogin,
          child: const Text(
            "Log In",
            style: TextStyle(
              color: Color(0xFF1E63FF),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}