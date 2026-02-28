import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _onboardingSeenKey = 'onboarding_seen';

  static Future<bool> getOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  static Future<void> setOnboardingSeen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, value);
  }

  // Useful for testing (optional)
  static Future<void> resetOnboarding() async {
    await setOnboardingSeen(false);
  }
}