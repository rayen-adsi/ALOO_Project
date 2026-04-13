// lib/screens/widgets/app_header.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/user_provider.dart';
import '../../core/notification_provider.dart';
import '../edit_profile_screen.dart';
import '../notifications_screen.dart';

class AppHeader extends StatelessWidget {
  final String? pageTitle;
  final Widget? customTitle;

  const AppHeader({super.key, this.pageTitle, this.customTitle});

  @override
  Widget build(BuildContext context) {
    final user   = context.watch<UserProvider>();
    final notifs = context.watch<NotificationProvider>();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Image.asset('assets/images/aloo_logo.png',
                  height: 60, fit: BoxFit.contain),
              const Spacer(),
              if (user.fullName.isNotEmpty)
                Text(user.fullName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(width: 10),

              // 🔔 Bell — reads from global NotificationProvider
              NotifBellWidget(unreadCount: notifs.unreadCount),
              const SizedBox(width: 10),

              GestureDetector(
                onTap: () => _openEditProfile(context),
                child: UserAvatar(
                  avatarIndex: user.avatarIndex,
                  photoPath:   user.photoPath,
                  size:        40,
                  showBorder:  true,
                ),
              ),
            ]),

            if (pageTitle != null) ...[
              const SizedBox(height: 16),
              Text(pageTitle!,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                    color: Color(0xFF1A3A6B), letterSpacing: -0.5)),
            ],
            if (customTitle != null) ...[
              const SizedBox(height: 16),
              customTitle!,
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditProfile(BuildContext context) async {
    final updated = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (updated == true && context.mounted) {
      await context.read<UserProvider>().load();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared bell widget — used by AppHeader, home_screen, provider_dashboard
// Takes the count directly so it always reflects the global provider
// ─────────────────────────────────────────────────────────────────────────────

class NotifBellWidget extends StatelessWidget {
  final int unreadCount;
  const NotifBellWidget({super.key, required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const NotificationsScreen(),
            transitionDuration: const Duration(milliseconds: 320),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: child),
          ),
        );
        // Refresh global badge when returning from notifications
        if (context.mounted) {
          context.read<NotificationProvider>().refresh();
        }
      },
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color:  Colors.white.withOpacity(0.18),
            shape:  BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.30), width: 1)),
          child: const Icon(Icons.notifications_rounded,
              color: Colors.white, size: 20)),
        if (unreadCount > 0)
          Positioned(
            top: -2, right: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color:        const Color(0xFFEF4444),
                shape:        unreadCount < 10 ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: unreadCount < 10 ? null : BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1.5)),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                    color: Colors.white, height: 1.1),
                textAlign: TextAlign.center))),
      ]),
    );
  }
}