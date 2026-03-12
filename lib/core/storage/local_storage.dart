// lib/core/storage/local_storage.dart
// ── Drop-in replacement — adds language helpers alongside existing ones ──────

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _keyOnboarding = 'onboarding_seen';
  static const _keyLanguage   = 'app_language';

  // ── Onboarding ──────────────────────────────────────────────────────────
  static Future<bool> getOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboarding) ?? false;
  }

  static Future<void> setOnboardingSeen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarding, value);
  }

  // ── Language ────────────────────────────────────────────────────────────
  static Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage);
  }

  static Future<void> setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, code);
  }

  /// true if a language has been explicitly selected by the user
  static Future<bool> hasLanguageBeenSelected() async {
    final lang = await getLanguage();
    return lang != null;
  }
}