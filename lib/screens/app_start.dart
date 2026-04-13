// lib/screens/app_start.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aloo_app/core/storage/local_storage.dart';
import 'package:aloo_app/core/storage/user_session.dart';
import 'package:aloo_app/core/user_provider.dart';
import 'package:aloo_app/core/notification_provider.dart';
import 'package:aloo_app/screens/onboarding_screen.dart';
import 'package:aloo_app/screens/sign_in_screen.dart';
import 'package:aloo_app/screens/home_screen.dart';
import 'package:aloo_app/screens/provider_home_screen.dart';
import 'package:aloo_app/screens/provider_setup_screen.dart';
import 'package:aloo_app/services/api_services.dart';
import 'package:aloo_app/services/reminder_service.dart';

class AppStart extends StatefulWidget {
  const AppStart({super.key});

  @override
  State<AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<AppStart> {
  static const bool kForceOnboarding = false;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final seen = await LocalStorage.getOnboardingSeen();

    if (!mounted) return;

    // Step 1: Show onboarding if not seen yet
    if (kForceOnboarding || !seen) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // Step 2: Check if user is already logged in (auto-login)
    final session = await UserSession.load();
    final int    userId = session['id']   ?? 0;
    final String role   = session['role'] ?? '';

    if (userId > 0 && role.isNotEmpty) {
      if (!mounted) return;

      // Load user data into global providers
      await context.read<UserProvider>().load();

      if (!mounted) return;

      // Load notification badge count
      await context.read<NotificationProvider>().load();

      if (!mounted) return;

      // Check for upcoming reservation reminders (silent — never blocks navigation)
      ReminderService.checkAndScheduleReminders().then((_) {
        // After reminders are created, refresh the notification badge
        if (mounted) {
          context.read<NotificationProvider>().refresh();
        }
      }).catchError((_) {});

      if (role == 'provider') {
        // Check if provider profile is complete
        try {
          final profile     = await ApiService.getProviderSettings(userId);
          final hasPhoto    = profile?['profile_photo'] != null;
          final hasBio      = (profile?['bio'] ?? '').toString().length >= 10;
          final hasSkills   = profile?['skills'] != null &&
              profile!['skills'].toString().isNotEmpty &&
              profile['skills'] != '[]';
          final hasPortfolio = profile?['portfolio'] != null &&
              profile!['portfolio'].toString().isNotEmpty &&
              profile['portfolio'] != '[]';

          if (!mounted) return;

          if (!hasPhoto || !hasBio || !hasSkills || !hasPortfolio) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProviderSetupScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProviderHomeScreen()),
            );
          }
        } catch (_) {
          // API error — go to provider home anyway
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProviderHomeScreen()),
          );
        }
      } else {
        // Client
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const homeScreen()),
        );
      }
      return;
    }

    // Step 3: Not logged in — go to sign in
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: Center(
        child: CircularProgressIndicator(
          color:       Color(0xFF2A5298),
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}