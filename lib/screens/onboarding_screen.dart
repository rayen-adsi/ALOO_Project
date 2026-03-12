// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/local_storage.dart';
import '../screens/widgets/lang_toggle_button.dart';
import 'sign_in_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  List<_OnboardingPageData> _buildPages(LanguageProvider lang) => [
    _OnboardingPageData(
      imagePath:  'assets/images/onboarding1.png',
      titleKey:   'onboarding1_title',
      subtitleKey:'onboarding1_subtitle',
    ),
    _OnboardingPageData(
      imagePath:  'assets/images/onboarding2.png',
      titleKey:   'onboarding2_title',
      subtitleKey:'onboarding2_subtitle',
    ),
    _OnboardingPageData(
      imagePath:  'assets/images/onboarding3.png',
      titleKey:   'onboarding3_title',
      subtitleKey:'onboarding3_subtitle',
    ),
  ];

  Future<void> _finishOnboarding() async {
    await LocalStorage.setOnboardingSeen(true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  void _next() {
    if (_index < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang  = context.watch<LanguageProvider>();
    final pages = _buildPages(lang);
    final data  = pages[_index];

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Illustration
                  Expanded(
                    flex: 6,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pages.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) {
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 18),
                          child: Image.asset(pages[i].imagePath,
                              fit: BoxFit.contain),
                        );
                      },
                    ),
                  ),

                  // Dots
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pages.length,
                        (i) => _Dot(active: i == _index),
                      ),
                    ),
                  ),

                  // Title + subtitle + button
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(22, 10, 22, 18),
                      child: Column(
                        children: [
                          Text(
                            lang.t(data.titleKey),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            lang.t(data.subtitleKey),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.4,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const Spacer(),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _next,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF0B63F6),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                _index < 2
                                    ? lang.t('next')
                                    : lang.t('get_started'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Language toggle top-right ──────────────────────────
              Positioned(
                top: 8,
                right: 12,
                child: LangToggleButton(
                  iconColor: const Color(0xFF2A4870),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: active ? 10 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF0B63F6)
            : const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _OnboardingPageData {
  final String imagePath;
  final String titleKey;
  final String subtitleKey;

  const _OnboardingPageData({
    required this.imagePath,
    required this.titleKey,
    required this.subtitleKey,
  });
}