// lib/screens/widgets/app_header.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/user_provider.dart';
import '../edit_profile_screen.dart';

class AppHeader extends StatelessWidget {
  /// Simple string title shown below logo row
  final String? pageTitle;
  /// Custom widget title (e.g. icon + text for favorites)
  final Widget? customTitle;

  const AppHeader({super.key, this.pageTitle, this.customTitle});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Logo + name + tappable avatar ─────────────────────
            Row(children: [
              Image.asset('assets/images/aloo_logo.png',
                  height: 60, fit: BoxFit.contain),
              const Spacer(),
              if (user.fullName.isNotEmpty)
                Text(user.fullName,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(width: 10),
              // Tappable avatar → opens edit profile
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

            // ── Page title ─────────────────────────────────────────
            if (pageTitle != null) ...[
              const SizedBox(height: 16),
              Text(pageTitle!,
                style: const TextStyle(
                  fontSize:   26, fontWeight: FontWeight.w900,
                  color:      Color(0xFF1A3A6B), letterSpacing: -0.5)),
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
      // Reload UserProvider → all pages update instantly
      await context.read<UserProvider>().load();
    }
  }
}