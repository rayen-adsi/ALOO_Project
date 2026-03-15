import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/l10n/language_provider.dart';
import 'core/user_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final languageProvider = LanguageProvider();
  await languageProvider.loadSavedLanguage();

  final userProvider = UserProvider();
  await userProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ],
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
      builder: (context, child) => Directionality(
        textDirection: lang.textDirection,
        child: child!,
      ),
      home: const SplashScreen(),
    );
  }
}