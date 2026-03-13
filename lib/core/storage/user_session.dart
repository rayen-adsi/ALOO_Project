// lib/core/storage/user_session.dart
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static const _keyFullName = 'session_full_name';
  static const _keyEmail    = 'session_email';
  static const _keyRole     = 'session_role';
  static const _keyId       = 'session_id';

  /// Save after successful login
  static Future<void> save({
    required String fullName,
    required String email,
    required String role,
    required int    id,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFullName, fullName);
    await prefs.setString(_keyEmail,    email);
    await prefs.setString(_keyRole,     role);
    await prefs.setInt   (_keyId,       id);
  }

  /// Load all session fields at once
  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'full_name': prefs.getString(_keyFullName) ?? '',
      'email':     prefs.getString(_keyEmail)    ?? '',
      'role':      prefs.getString(_keyRole)     ?? 'client',
      'id':        prefs.getInt   (_keyId)       ?? 0,
    };
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

  static Future<int> getId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyId) ?? 0;
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
    await prefs.remove(_keyId);
  }
}