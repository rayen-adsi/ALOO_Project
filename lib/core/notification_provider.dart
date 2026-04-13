// lib/core/notification_provider.dart

import 'package:flutter/material.dart';
import 'storage/user_session.dart';
import '../services/api_services.dart';

/// Global notification state — all bells listen to this.
/// Call refresh() from anywhere to update the badge instantly.
class NotificationProvider extends ChangeNotifier {
  int    _unreadCount = 0;
  int    _userId      = 0;
  String _userType    = 'client';

  int get unreadCount => _unreadCount;

  /// Call once at startup and after login
  Future<void> load() async {
    final session = await UserSession.load();
    _userId   = session['id']   ?? 0;
    _userType = session['role'] ?? 'client';
    await refresh();
  }

  /// Fetch fresh count from backend — call after marking read
  Future<void> refresh() async {
    if (_userId == 0) return;
    try {
      final notifs = await ApiService.getNotifications(
          userId: _userId, userType: _userType);
      _unreadCount = notifs.where((n) => n['is_read'] == false).length;
      notifyListeners();
    } catch (_) {}
  }

  /// Instantly set to zero without a network call (optimistic update)
  void clearBadge() {
    _unreadCount = 0;
    notifyListeners();
  }

  /// Clear on logout
  void clear() {
    _unreadCount = 0;
    _userId      = 0;
    _userType    = 'client';
    notifyListeners();
  }
}