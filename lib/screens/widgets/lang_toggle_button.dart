// lib/widgets/lang_toggle_button.dart
// ── Drop this anywhere in a Stack/AppBar to get the language toggle ──────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/language_provider.dart';

class LangToggleButton extends StatelessWidget {
  /// Icon color — use light color on dark bg, dark on light bg
  final Color iconColor;

  const LangToggleButton({
    super.key,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return GestureDetector(
      onTap: () => _showLanguageSheet(context, lang),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
        ),
        child: Center(
          child: Text(
            _flagEmoji(lang.langCode),
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  String _flagEmoji(String code) {
    switch (code) {
      case 'fr': return '🇫🇷';
      case 'ar': return '🇹🇳';
      default:   return '🇬🇧';
    }
  }

  void _showLanguageSheet(BuildContext context, LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguageSheet(lang: lang),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LanguageSheet extends StatelessWidget {
  final LanguageProvider lang;
  const _LanguageSheet({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            lang.t('choose_language'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),

          _LangOption(
            emoji: '🇬🇧',
            label: lang.t('lang_english'),
            code: 'en',
            selected: lang.langCode == 'en',
            onTap: () { lang.setLanguage('en'); Navigator.pop(context); },
          ),
          const SizedBox(height: 10),
          _LangOption(
            emoji: '🇫🇷',
            label: lang.t('lang_french'),
            code: 'fr',
            selected: lang.langCode == 'fr',
            onTap: () { lang.setLanguage('fr'); Navigator.pop(context); },
          ),
          const SizedBox(height: 10),
          _LangOption(
            emoji: '🇹🇳',
            label: lang.t('lang_arabic'),
            code: 'ar',
            selected: lang.langCode == 'ar',
            onTap: () { lang.setLanguage('ar'); Navigator.pop(context); },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String emoji;
  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  const _LangOption({
    required this.emoji,
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : const Color(0xFFE5E7EB),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF374151),
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF3B82F6), size: 20),
          ],
        ),
      ),
    );
  }
}