// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import 'sign_in_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _fullName = '';
  String _email    = '';

  // Notification toggles
  bool _notifBookings  = true;
  bool _notifMessages  = true;
  bool _notifPromo     = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name  = await UserSession.getFullName();
    final email = await UserSession.getEmail();
    if (mounted) {
      setState(() {
        _fullName = name  ?? '';
        _email    = email ?? '';
      });
    }
  }

  Future<void> _logout() async {
    final lang = context.read<LanguageProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(lang.t('logout'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(lang.t('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.t('cancel'),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.t('logout'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await UserSession.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (_) => false,
      );
    }
  }

  void _showChangePassword() {
    final lang       = context.read<LanguageProvider>();
    final oldCtrl    = TextEditingController();
    final newCtrl    = TextEditingController();
    final confirmCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(lang.t('change_password'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: Color(0xFF1A3A6B))),
              const SizedBox(height: 20),
              _PassField(ctrl: oldCtrl,     hint: lang.t('current_password')),
              const SizedBox(height: 12),
              _PassField(ctrl: newCtrl,     hint: lang.t('new_password')),
              const SizedBox(height: 12),
              _PassField(ctrl: confirmCtrl, hint: lang.t('confirm_password')),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A3A6B),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    // TODO: wire to backend change password endpoint
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lang.t('coming_soon'))),
                    );
                  },
                  child: Text(lang.t('save'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.80),
                      Colors.white.withOpacity(0.97),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Header ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Text(
                        lang.t('settings'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A3A6B),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Profile card ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1A3A6B), Color(0xFF2A5298)],
                                ),
                              ),
                              child: const Icon(Icons.person_rounded,
                                  color: Colors.white, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _fullName.isNotEmpty ? _fullName : '—',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A3A6B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _email.isNotEmpty ? _email : '—',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Language section ────────────────────────────
                    _SectionTitle(title: lang.t('language')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _LangOption(
                              flag: '🇬🇧', label: 'English', code: 'en',
                              current: lang.langCode,
                              onTap: () => lang.setLanguage('en'),
                            ),
                            _Divider(),
                            _LangOption(
                              flag: '🇫🇷', label: 'Français', code: 'fr',
                              current: lang.langCode,
                              onTap: () => lang.setLanguage('fr'),
                            ),
                            _Divider(),
                            _LangOption(
                              flag: '🇸🇦', label: 'العربية', code: 'ar',
                              current: lang.langCode,
                              onTap: () => lang.setLanguage('ar'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Notifications section ───────────────────────
                    _SectionTitle(title: lang.t('notifications')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _ToggleRow(
                              icon: Icons.calendar_today_rounded,
                              iconColor: const Color(0xFF2A5298),
                              label: lang.t('notif_bookings'),
                              value: _notifBookings,
                              onChanged: (v) => setState(() => _notifBookings = v),
                            ),
                            _Divider(),
                            _ToggleRow(
                              icon: Icons.chat_bubble_outline_rounded,
                              iconColor: const Color(0xFF10B981),
                              label: lang.t('notif_messages'),
                              value: _notifMessages,
                              onChanged: (v) => setState(() => _notifMessages = v),
                            ),
                            _Divider(),
                            _ToggleRow(
                              icon: Icons.local_offer_outlined,
                              iconColor: const Color(0xFFF59E0B),
                              label: lang.t('notif_promo'),
                              value: _notifPromo,
                              onChanged: (v) => setState(() => _notifPromo = v),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Account section ─────────────────────────────
                    _SectionTitle(title: lang.t('account')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _ActionRow(
                              icon: Icons.lock_outline_rounded,
                              iconColor: const Color(0xFF8B5CF6),
                              label: lang.t('change_password'),
                              onTap: _showChangePassword,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── About section ───────────────────────────────
                    _SectionTitle(title: lang.t('about')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.info_outline_rounded,
                              iconColor: const Color(0xFF0EA5E9),
                              label: lang.t('app_version'),
                              value: '1.0.0',
                            ),
                            _Divider(),
                            _InfoRow(
                              icon: Icons.business_rounded,
                              iconColor: const Color(0xFF64748B),
                              label: lang.t('made_by'),
                              value: 'ALOO Team',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Logout button ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red.shade600,
                            elevation: 0,
                            side: BorderSide(color: Colors.red.shade200),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(
                            lang.t('logout'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 56, color: Colors.grey.shade100);
  }
}

class _LangOption extends StatelessWidget {
  final String flag, label, code, current;
  final VoidCallback onTap;

  const _LangOption({
    required this.flag, required this.label, required this.code,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == code;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B))),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2A5298), size: 22),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon, required this.iconColor,
    required this.label, required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B))),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2A5298),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon, required this.iconColor,
    required this.label, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B))),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 22),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;

  const _InfoRow({
    required this.icon, required this.iconColor,
    required this.label, required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B))),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _PassField extends StatefulWidget {
  final TextEditingController ctrl;
  final String hint;
  const _PassField({required this.ctrl, required this.hint});

  @override
  State<_PassField> createState() => _PassFieldState();
}

class _PassFieldState extends State<_PassField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.ctrl,
      obscureText: _obscure,
      decoration: InputDecoration(
        hintText: widget.hint,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey),
        ),
      ),
    );
  }
}