// lib/screens/sign_in_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../services/api_services.dart';
import '../core/storage/user_session.dart';
import '../screens/widgets/lang_toggle_button.dart';
import 'home_screen.dart';
import 'signup_role_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoY;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _formY;
  late final Animation<double> _formOpacity;

  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _logoY = Tween<double>(begin: 50, end: -140).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _logoOpacity = CurvedAnimation(parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _formY = Tween<double>(begin: 220, end: 0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic)));
    _formOpacity = CurvedAnimation(parent: _controller,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final lang = context.read<LanguageProvider>();

    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _showMessage(lang.t('fill_all_fields'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result =
          await ApiService.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      _showMessage(result['message']);
      if (result['success'] == true) {
        // Save session from login response
        await UserSession.save(
          fullName: result['full_name'] ?? '',
          email:    result['email']     ?? _emailCtrl.text.trim(),
          role:     result['role']      ?? 'client',
        );
        if (!mounted) return;
        Navigator.pushReplacement(context,
            MaterialPageRoute(
              builder: (_) => homeScreen(
                fullName: result['full_name'] ?? '',
              ),
            ));
      }
    } catch (_) {
      if (mounted) _showMessage(lang.t('connection_error'));
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    const Color primaryBlue = Color(0xFF2A4870);
    const Color lightBlue   = Color(0xFF8CD6E7);

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/bg.png', fit: BoxFit.cover)),
            Positioned.fill(
              child: Container(color: primaryBlue.withOpacity(0.25))),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primaryBlue.withOpacity(0.65),
                      lightBlue.withOpacity(0.10),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Stack(
                children: [
                  // ── Animated logo + form ─────────────────────────
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return Stack(
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Opacity(
                              opacity: _logoOpacity.value,
                              child: Transform.translate(
                                offset: Offset(0, _logoY.value),
                                child: Image.asset(
                                    'assets/images/aloo_logo.png',
                                    width: 240, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Opacity(
                              opacity: _formOpacity.value,
                              child: Transform.translate(
                                offset: Offset(0, _formY.value),
                                child: _SignInCard(
                                  lang: lang,
                                  emailCtrl: _emailCtrl,
                                  passCtrl: _passCtrl,
                                  obscurePassword: _obscurePassword,
                                  isLoading: _isLoading,
                                  onTogglePassword: () => setState(
                                      () => _obscurePassword =
                                          !_obscurePassword),
                                  onSignIn: _isLoading
                                      ? null
                                      : _handleSignIn,
                                  onForgot: () {},
                                  onGoToSignUp: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const SignUpRoleScreen()),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // ── Language toggle top-right ────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────

class _SignInCard extends StatelessWidget {
  final LanguageProvider lang;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback? onSignIn;
  final VoidCallback onForgot;
  final VoidCallback onGoToSignUp;

  const _SignInCard({
    required this.lang,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscurePassword,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onSignIn,
    required this.onForgot,
    required this.onGoToSignUp,
  });

  @override
  Widget build(BuildContext context) {
    InputDecoration baseDecoration(String hint, {Widget? suffixIcon}) {
      return InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: suffixIcon,
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lang.t('sign_in'),
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: baseDecoration(lang.t('email')),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: passCtrl,
            obscureText: obscurePassword,
            decoration: baseDecoration(
              lang.t('password'),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    key: ValueKey(obscurePassword),
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onForgot,
              child: Text(
                lang.t('forgot_password'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 6),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B63F6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      lang.t('sign_in'),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(lang.t('new_here')),
              TextButton(
                onPressed: onGoToSignUp,
                child: Text(
                  lang.t('create_account'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}