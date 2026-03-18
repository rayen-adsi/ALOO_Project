// lib/core/user_provider.dart

import 'package:flutter/material.dart';
import 'storage/user_session.dart';
import '../services/api_services.dart';

/// Global user state — all pages listen to this.
/// When avatar or name changes, all pages rebuild instantly.
class UserProvider extends ChangeNotifier {
  String  _fullName    = '';
  String  _email       = '';
  String  _role        = 'client';
  int     _userId      = 0;
  int     _avatarIndex = 0;
  String? _photoPath;

  String  get fullName    => _fullName;
  String  get email       => _email;
  String  get role        => _role;
  int     get userId      => _userId;
  int     get avatarIndex => _avatarIndex;
  String? get photoPath   => _photoPath;

  /// Load from session + fetch photo from backend
  Future<void> load() async {
    final s  = await UserSession.load();
    _fullName    = s['full_name']    ?? '';
    _email       = s['email']        ?? '';
    _role        = s['role']         ?? 'client';
    _userId      = s['id']           ?? 0;
    _avatarIndex = s['avatar_index'] ?? 0;

    // ✅ FIX: Fetch the profile photo from the backend
    if (_userId > 0) {
      try {
        Map<String, dynamic>? profile;
        if (_role == 'client') {
          profile = await ApiService.getClient(_userId);
        } else {
          profile = await ApiService.getProviderSettings(_userId);
        }
        if (profile != null && profile['profile_photo'] != null) {
          _photoPath = profile['profile_photo'] as String;
        }
      } catch (_) {
        // If network fails, keep photoPath as null — avatar will show instead
      }
    }

    notifyListeners();
  }

  /// Call after saving profile — all listeners rebuild instantly
  void update({
    String?  fullName,
    int?     avatarIndex,
    String?  photoPath,
  }) {
    if (fullName    != null) _fullName    = fullName;
    if (avatarIndex != null) _avatarIndex = avatarIndex;
    _photoPath = photoPath;
    notifyListeners();
  }

  /// Clear on logout
  void clear() {
    _fullName    = '';
    _email       = '';
    _role        = 'client';
    _userId      = 0;
    _avatarIndex = 0;
    _photoPath   = null;
    notifyListeners();
  }
}