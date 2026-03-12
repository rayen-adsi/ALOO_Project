// lib/core/storage/user_session.dart

import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static const _keyFullName = 'session_full_name';
  static const _keyEmail    = 'session_email';
  static const _keyRole     = 'session_role';

  /// Save after successful login
  static Future<void> save({
    required String fullName,
    required String email,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullName, fullName);
    await prefs.setString(_keyEmail,    email);
    await prefs.setString(_keyRole,     role);
  }

  static Future<String?> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullName);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyFullName);
  }

  /// Call on logout
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
  }
}