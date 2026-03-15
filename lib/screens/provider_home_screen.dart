// lib/screens/provider_home_screen.dart
// Main shell for providers — different bottom nav than clients.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../core/user_provider.dart';
import 'provider_dashboard_tab.dart';
import 'provider_reservations_tab.dart';
import 'conversations_screen.dart';
import 'settings_screen.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  int _currentNav = 0;

  int    _userId   = 0;
  String _userRole = 'provider';

  final _convKey = GlobalKey<ConversationsScreenState>();

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await UserSession.load();
    if (!mounted) return;
    setState(() {
      _userId   = session['id']   ?? 0;
      _userRole = session['role'] ?? 'provider';
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final List<Widget> tabs = [
      ProviderDashboardTab(userId: _userId),
      ProviderReservationsTab(userId: _userId),
      ConversationsScreen(
        key:      _convKey,
        userId:   _userId,
        userRole: _userRole,
      ),
      const SettingsScreen(),
    ];

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: IndexedStack(index: _currentNav, children: tabs),
        bottomNavigationBar: _ProviderBottomNav(
          currentIndex: _currentNav,
          lang:         lang,
          onTap: (i) {
            setState(() => _currentNav = i);
            if (i == 2) _convKey.currentState?.reload();
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER BOTTOM NAV — 4 tabs: Dashboard, Reservations, Messages, Settings
// ─────────────────────────────────────────────────────────────────────────────

class _ProviderBottomNav extends StatelessWidget {
  final int              currentIndex;
  final LanguageProvider lang;
  final ValueChanged<int> onTap;

  const _ProviderBottomNav({
    required this.currentIndex,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(
        icon:       Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label:      lang.t('dashboard'),
      ),
      _NavItem(
        icon:       Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today_rounded,
        label:      lang.t('reservations'),
      ),
      _NavItem(
        icon:       Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label:      lang.t('messaging'),
      ),
      _NavItem(
        icon:       Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label:      lang.t('settings'),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = currentIndex == i;
              final item     = items[i];
              return GestureDetector(
                onTap:    () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 68,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Active indicator line
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width:  isActive ? 32 : 0,
                        height: isActive ? 3  : 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color:        const Color(0xFF2A5298),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        color: isActive
                            ? const Color(0xFF2A5298)
                            : const Color(0xFF94A3B8),
                        size: 23,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize:   10,
                          fontWeight: isActive
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: isActive
                              ? const Color(0xFF2A5298)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}