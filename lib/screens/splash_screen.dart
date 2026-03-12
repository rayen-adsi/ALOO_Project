// lib/screens/splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../core/storage/local_storage.dart';
import 'language_select_screen.dart';
import 'app_start.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> pinY;
  late final Animation<double> pinScale;
  late final Animation<double> pinOpacity;
  late final Animation<double> lettersOpacity;
  late final Animation<double> leftX;
  late final Animation<double> rightX;
  late final Animation<double> finalHoldOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    pinY = Tween<double>(begin: -650.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.00, 0.45, curve: Curves.easeOutCubic)));

    pinScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.00, 0.45, curve: Curves.easeOutBack)));

    pinOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.00, 0.18, curve: Curves.easeOut)));

    lettersOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.50, 0.70, curve: Curves.easeOut)));

    leftX = Tween<double>(begin: 0.0, end: -80.0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.50, 0.90, curve: Curves.easeOutCubic)));

    rightX = Tween<double>(begin: 0.0, end: 105.0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.50, 0.90, curve: Curves.easeOutCubic)));

    finalHoldOpacity = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.90, 1.00)));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward();
    });

    // After splash ends, decide where to go
    Timer(const Duration(seconds: 6), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final languageAlreadySelected =
        await LocalStorage.hasLanguageBeenSelected();

    if (!mounted) return;

    final destination = languageAlreadySelected
        ? const AppStart()
        : const LanguageSelectScreen();

    Navigator.of(context).pushReplacement(_fadeRoute(destination));
  }

  PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2A4870);
    const Color lightBlue   = Color(0xFF8CD6E7);
    const double logoW = 417;
    const double logoH = 291;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: primaryBlue.withOpacity(0.25)),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primaryBlue.withOpacity(0.65),
                    lightBlue.withOpacity(0.10),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Opacity(
                    opacity: finalHoldOpacity.value,
                    child: SizedBox(
                      width: logoW,
                      height: logoH,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: lettersOpacity.value,
                            child: Transform.translate(
                              offset: Offset(leftX.value, 0),
                              child: Image.asset('assets/images/logo_left.png',
                                  height: logoH, fit: BoxFit.contain),
                            ),
                          ),
                          Opacity(
                            opacity: lettersOpacity.value,
                            child: Transform.translate(
                              offset: Offset(rightX.value, 0),
                              child: Image.asset('assets/images/logo_right.png',
                                  height: logoH, fit: BoxFit.contain),
                            ),
                          ),
                          Opacity(
                            opacity: pinOpacity.value,
                            child: Transform.translate(
                              offset: Offset(25, pinY.value),
                              child: Transform.scale(
                                scale: pinScale.value,
                                child: Image.asset('assets/images/logo_pin.png',
                                    height: logoH, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}