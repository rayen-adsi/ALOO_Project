import 'package:flutter/material.dart';

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
  final _passCtrl = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    // Logo slides up (center -> top)
    _logoY = Tween<double>(begin: 50, end: -140).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    // Form slides up later (bottom -> place)
    _formY = Tween<double>(begin: 220, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _formOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
    );

    // Start after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _togglePassword() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2A4870);
    const Color lightBlue = Color(0xFF8CD6E7);

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // Global tint overlay
          Positioned.fill(
            child: Container(
              color: primaryBlue.withOpacity(0.25),
            ),
          ),

          // Gradient overlay
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
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Stack(
                  children: [
                    // LOGO (slides up)
                    Align(
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _logoY.value),
                          child: Image.asset(
                            'assets/images/aloo_logo.png',
                            width: 240,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    // FORM (slides up from bottom)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Opacity(
                        opacity: _formOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _formY.value),
                          child: _SignInCard(
                            emailCtrl: _emailCtrl,
                            passCtrl: _passCtrl,
                            obscurePassword: _obscurePassword,
                            onTogglePassword: _togglePassword,
                            onSignIn: () {
                              // TODO: implement sign in
                            },
                            onForgot: () {
                              // TODO: navigate to forgot password
                            },
                            onGoToSignUp: () {
                              // TODO: navigate to sign up
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;

  final bool obscurePassword;
  final VoidCallback onTogglePassword;

  final VoidCallback onSignIn;
  final VoidCallback onForgot;
  final VoidCallback onGoToSignUp;

  const _SignInCard({
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscurePassword,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          const Text(
            "Sign in",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: baseDecoration("Email"),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: passCtrl,
            obscureText: obscurePassword,
            decoration: baseDecoration(
              "Password",
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
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
              child: const Text(
                "Forgot password?",
                style: TextStyle(fontWeight: FontWeight.w700),
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
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Sign in",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("New here? "),
              TextButton(
                onPressed: onGoToSignUp,
                child: const Text(
                  "Create account",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}