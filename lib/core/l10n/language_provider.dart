// lib/core/l10n/language_provider.dart

import 'package:flutter/material.dart';
import '../../../core/storage/local_storage.dart';
import 'app_translations.dart';

class LanguageProvider extends ChangeNotifier {
  String _langCode = 'en'; // default

  String get langCode => _langCode;

  bool get isArabic => _langCode == 'ar';
  TextDirection get textDirection =>
      _langCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

  /// Call once at startup to load saved language
  Future<void> loadSavedLanguage() async {
    final saved = await LocalStorage.getLanguage();
    if (saved != null && ['en', 'fr', 'ar'].contains(saved)) {
      _langCode = saved;
      notifyListeners();
    }
  }

  /// Change language and persist it
  Future<void> setLanguage(String code) async {
    if (_langCode == code) return;
    _langCode = code;
    await LocalStorage.setLanguage(code);
    notifyListeners();
  }

  /// Translate a key
  String t(String key) {
    return appTranslations[key]?[_langCode] ??
        appTranslations[key]?['en'] ??
        key;
  }
}