// lib/screens/provider_home_screen.dart
//
// Provider's main shell — 5-tab bottom nav:
//   0. Dashboard     (ProviderDashboardTab)
//   1. Reservations  (ProviderReservationsTab)
//   2. Map           (ProviderClientMapScreen) ← NEW — clients with accepted reservations
//   3. Conversations (ConversationsScreen)
//   4. Settings      (SettingsScreen)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import 'provider_dashboard_tab.dart';
import 'provider_reservations_tab.dart';
import 'provider_client_map_screen.dart';
import 'conversations_screen.dart';
import 'chatbot_screen.dart';
import 'settings_screen.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {

  int    _currentNav = 0;
  int    _userId     = 0;
  String _userRole   = 'provider';

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

    // Build tabs lazily — userId may be 0 briefly while session loads,
    // widgets handle that gracefully.
    final tabs = <Widget>[
      // 0 — Dashboard
      ProviderDashboardTab(userId: _userId),

      // 1 — Reservations
      ReservationsTab(userId: _userId, userRole: _userRole),

      // 2 — Client map (accepted reservations only)
      SizedBox.expand(
        child: ProviderClientMapScreen(providerId: _userId),
      ),

      // 3 — Conversations
      ConversationsScreen(
        key:      _convKey,
        userId:   _userId,
        userRole: _userRole,
      ),

      // 4 — Settings
      const SettingsScreen(),
    ];

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: IndexedStack(index: _currentNav, children: tabs),
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentNav,
          onTap: (i) {
            setState(() => _currentNav = i);
            if (i == 3) _convKey.currentState?.reload();
          },
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FloatingActionButton(
            heroTag: 'chatbot-fab-provider',
            backgroundColor: const Color(0xFF1A3A6B),
            foregroundColor: Colors.white,
            tooltip: 'Open assistant',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatbotScreen(userRole: _userRole),
                ),
              );
            },
            child: const Icon(Icons.smart_toy_rounded),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation — 5 items
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int                currentIndex;
  final ValueChanged<int>  onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      // 0 — Dashboard
      {'icon': Icons.dashboard_outlined,          'active': Icons.dashboard_rounded},
      // 1 — Reservations
      {'icon': Icons.calendar_month_outlined,     'active': Icons.calendar_month_rounded},
      // 2 — Map (clients)
      {'icon': Icons.location_on_outlined,        'active': Icons.location_on_rounded},
      // 3 — Conversations
      {'icon': Icons.chat_bubble_outline_rounded, 'active': Icons.chat_bubble_rounded},
      // 4 — Settings
      {'icon': Icons.settings_outlined,           'active': Icons.settings_rounded},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20, offset: const Offset(0, -4))]),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = currentIndex == i;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 52,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width:  isActive ? 40 : 0,
                        height: isActive ? 4  : 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color:        Colors.black,
                          borderRadius: BorderRadius.circular(4))),
                      Icon(
                        isActive
                            ? items[i]['active'] as IconData
                            : items[i]['icon']   as IconData,
                        color: Colors.black, size: 24),
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