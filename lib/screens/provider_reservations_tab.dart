// lib/screens/provider_reservations_tab.dart
// Placeholder for the reservations tab — will be fully built
// when we implement the Service Offer system in chat.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';

class ProviderReservationsTab extends StatefulWidget {
  final int userId;
  const ProviderReservationsTab({super.key, required this.userId});

  @override
  State<ProviderReservationsTab> createState() =>
      _ProviderReservationsTabState();
}

class _ProviderReservationsTabState extends State<ProviderReservationsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/bg.png', fit: BoxFit.cover)),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.75),
                    Colors.white.withOpacity(0.97),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:      Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset:     const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          color: Color(0xFF2A5298),
                          size:  18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        lang.t('reservations'),
                        style: const TextStyle(
                          fontSize:   26,
                          fontWeight: FontWeight.w900,
                          color:      Color(0xFF1A3A6B),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Empty state ─────────────────────────────────
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:      Colors.black.withOpacity(0.07),
                                blurRadius: 16,
                                offset:     const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.event_note_rounded,
                            size:  42,
                            color: Color(0xFF2A5298),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          lang.t('no_reservations'),
                          style: const TextStyle(
                            fontSize:   17,
                            fontWeight: FontWeight.w700,
                            color:      Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 50),
                          child: Text(
                            lang.t('no_reservations_sub'),
                            style: TextStyle(
                              fontSize: 13.5,
                              color:    Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}