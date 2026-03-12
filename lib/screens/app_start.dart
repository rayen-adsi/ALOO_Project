// lib/screens/app_start.dart

import 'package:flutter/material.dart';
import 'package:aloo_app/core/storage/local_storage.dart';
import 'package:aloo_app/screens/onboarding_screen.dart';
import 'package:aloo_app/screens/sign_in_screen.dart';

class AppStart extends StatefulWidget {
  const AppStart({super.key});

  @override
  State<AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<AppStart> {
  // ✅ DEV TOGGLE:
  // true  => Onboarding always shows (best while building)
  // false => Onboarding shows only once (production behavior)
  static const bool kForceOnboarding = false;

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

    // Onboarding already seen → go straight to sign in
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}