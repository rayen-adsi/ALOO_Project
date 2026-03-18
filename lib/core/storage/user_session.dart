// lib/core/storage/user_session.dart

import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static const _keyId           = 'session_id';
  static const _keyFullName     = 'session_full_name';
  static const _keyEmail        = 'session_email';
  static const _keyRole         = 'session_role';

  // ✅ FIX: Avatar is now stored per user using "avatar_<userId>" key
  static String _avatarKey(int userId) => 'avatar_$userId';

  static Future<void> save({
    required int    id,
    required String fullName,
    required String email,
    required String role,
    int             avatarIndex = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(   _keyId,          id);
    await prefs.setString(_keyFullName,    fullName);
    await prefs.setString(_keyEmail,       email);
    await prefs.setString(_keyRole,        role);
    await prefs.setInt(   _avatarKey(id),  avatarIndex);
  }

  static Future<Map<String, dynamic>> load() async {
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyId) ?? 0;
    return {
      'id':           userId,
      'full_name':    prefs.getString(_keyFullName) ?? '',
      'email':        prefs.getString(_keyEmail)    ?? '',
      'role':         prefs.getString(_keyRole)     ?? 'client',
      'avatar_index': prefs.getInt(_avatarKey(userId)) ?? 0,
    };
  }

  static Future<int>    getId()        async => (await SharedPreferences.getInstance()).getInt(_keyId) ?? 0;
  static Future<String?> getFullName() async => (await SharedPreferences.getInstance()).getString(_keyFullName);
  static Future<String?> getRole()     async => (await SharedPreferences.getInstance()).getString(_keyRole);

  static Future<int> getAvatarIndex() async {
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyId) ?? 0;
    return prefs.getInt(_avatarKey(userId)) ?? 0;
  }

  static Future<bool> isLoggedIn() async =>
      (await SharedPreferences.getInstance()).containsKey(_keyFullName);

  static Future<void> saveAvatarIndex(int index) async {
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyId) ?? 0;
    if (userId > 0) {
      await prefs.setInt(_avatarKey(userId), index);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    // Note: we do NOT remove avatar keys — they persist per user
    await prefs.remove(_keyId);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
  }
}