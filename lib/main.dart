import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/l10n/language_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final languageProvider = LanguageProvider();
  await languageProvider.loadSavedLanguage();

  runApp(
    ChangeNotifierProvider<LanguageProvider>.value(
      value: languageProvider,
      child: const AlooApp(),
    ),
  );
}

class AlooApp extends StatelessWidget {
  const AlooApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(
          textDirection: lang.textDirection,
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}