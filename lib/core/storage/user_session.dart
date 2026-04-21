// lib/core/storage/user_session.dart

import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static const _keyId       = 'session_id';
  static const _keyFullName = 'session_full_name';
  static const _keyEmail    = 'session_email';
  static const _keyRole     = 'session_role';

  // Avatar is stored per user and role
  static String _avatarKey(int userId, String role) => 'avatar_${role}_$userId';

  // Location is stored per user and role so switching accounts never overwrites each other
  static String _locLatKey (int userId, String role) => 'loc_lat_${role}_$userId';
  static String _locLngKey (int userId, String role) => 'loc_lng_${role}_$userId';
  static String _locCityKey(int userId, String role) => 'loc_city_${role}_$userId';
  static String _locSetKey (int userId, String role) => 'loc_set_${role}_$userId';

  // ── Save session after login ─────────────────────────────────────────────

  static Future<void> save({
    required int    id,
    required String fullName,
    required String email,
    required String role,
    int             avatarIndex = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(   _keyId,         id);
    await prefs.setString(_keyFullName,   fullName);
    await prefs.setString(_keyEmail,      email);
    await prefs.setString(_keyRole,       role);
    await prefs.setInt(   _avatarKey(id, role), avatarIndex);
  }

  // ── Load session ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> load() async {
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyId) ?? 0;
    final role   = prefs.getString(_keyRole) ?? 'client';
    return {
      'id':           userId,
      'full_name':    prefs.getString(_keyFullName) ?? '',
      'email':        prefs.getString(_keyEmail)    ?? '',
      'role':         role,
      'avatar_index': prefs.getInt(_avatarKey(userId, role)) ?? 0,
      // Location — scoped per user ID and role so accounts with same SQL IDs stay independent
      'lat':          prefs.getDouble(_locLatKey(userId, role)),
      'lng':          prefs.getDouble(_locLngKey(userId, role)),
      'city':         prefs.getString(_locCityKey(userId, role)) ?? '',
      'location_set': prefs.getBool(_locSetKey(userId, role))    ?? false,
    };
  }

  // ── Convenience getters ───────────────────────────────────────────────────

  static Future<int>     getId()       async =>
      (await SharedPreferences.getInstance()).getInt(_keyId) ?? 0;

  static Future<String?> getFullName() async =>
      (await SharedPreferences.getInstance()).getString(_keyFullName);

  static Future<String?> getRole()     async =>
      (await SharedPreferences.getInstance()).getString(_keyRole);

  static Future<int> getAvatarIndex() async {
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyId) ?? 0;
    final role   = prefs.getString(_keyRole) ?? 'client';
    return prefs.getInt(_avatarKey(userId, role)) ?? 0;
  }

  static Future<bool> isLoggedIn() async =>
      (await SharedPreferences.getInstance()).containsKey(_keyFullName);

  static Future<void> saveAvatarIndex(int index) async {
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyId) ?? 0;
    final role   = prefs.getString(_keyRole) ?? 'client';
    if (userId > 0) {
      await prefs.setInt(_avatarKey(userId, role), index);
    }
  }

  /// Save confirmed pin location locally — scoped to the currently logged-in user and role.
  static Future<void> saveLocation({
    required double lat,
    required double lng,
    String          city = '',
  }) async {
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyId) ?? 0;
    final role   = prefs.getString(_keyRole) ?? 'client';
    if (userId == 0) return; // no session, ignore
    await prefs.setDouble(_locLatKey(userId, role),  lat);
    await prefs.setDouble(_locLngKey(userId, role),  lng);
    await prefs.setString(_locCityKey(userId, role), city);
    await prefs.setBool(  _locSetKey(userId, role),  true);
  }

  /// Read saved location for the currently logged-in user.
  static Future<Map<String, dynamic>> getLocationData() async {
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyId) ?? 0;
    final role   = prefs.getString(_keyRole) ?? 'client';
    return {
      'lat':          prefs.getDouble(_locLatKey(userId, role)),
      'lng':          prefs.getDouble(_locLngKey(userId, role)),
      'city':         prefs.getString(_locCityKey(userId, role)) ?? '',
      'location_set': prefs.getBool(_locSetKey(userId, role))    ?? false,
    };
  }

  // ── Clear on logout ───────────────────────────────────────────────────────

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    // Note: avatar keys are NOT removed — they persist per user.
    // Note: location keys are NOT removed — location is saved permanently
    //       and only changes when the user explicitly presses "Change Location".
    //       The backend is always checked on next login, so this stays in sync.
    await prefs.remove(_keyId);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
  }
}