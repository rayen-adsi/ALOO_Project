import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';


void main() => runApp(const AlooApp());

class AlooApp extends StatelessWidget {
  const AlooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}