import 'package:flutter/material.dart';
import '../core/storage/local_storage.dart';
import 'onboarding_screen.dart';
import 'auth_screen.dart';

class AppStart extends StatefulWidget {
  const AppStart({super.key});

  @override
  State<AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<AppStart> {
  // ✅ DEV TOGGLE:
  // true  => Onboarding always shows (best while building)
  // false => Onboarding shows only once (production behavior)
  static const bool kForceOnboarding = true;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final seen = await LocalStorage.getOnboardingSeen();

    if (!mounted) return;

    if (kForceOnboarding || !seen) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // Later: if token exists -> go to Home
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}