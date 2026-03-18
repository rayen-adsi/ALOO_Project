// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import '../core/user_provider.dart';
import 'sign_in_screen.dart';
import 'edit_profile_screen.dart';
import 'provider_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _fullName    = '';
  int    _avatarIndex = 0;
  String _email    = '';
  String _role     = 'client';
  int    _userId   = 0;

  bool _notifBookings = true;
  bool _notifMessages = true;
  bool _notifPromo    = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final session = await UserSession.load();
    if (mounted) {
      setState(() {
        _fullName    = session['full_name']    ?? '';
        _avatarIndex = session['avatar_index'] ?? 0;
        _email    = session['email']     ?? '';
        _role     = session['role']      ?? 'client';
        _userId   = session['id']        ?? 0;
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
      context.read<UserProvider>().clear();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (_) => false,
      );
    }
  }

  void _showChangePassword() {
    final lang        = context.read<LanguageProvider>();
    final oldCtrl     = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool  isLoading   = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
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
                    onPressed: isLoading ? null : () async {
                      if (oldCtrl.text.isEmpty ||
                          newCtrl.text.isEmpty ||
                          confirmCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(lang.t('fill_all_fields'))),
                        );
                        return;
                      }
                      setSheetState(() => isLoading = true);
                      Map<String, dynamic> result;
                      if (_role == 'client') {
                        result = await ApiService.changeClientPassword(
                          clientId:        _userId,
                          currentPassword: oldCtrl.text,
                          newPassword:     newCtrl.text,
                          newPassword2:    confirmCtrl.text,
                        );
                      } else {
                        result = await ApiService.changeProviderPassword(
                          providerId:      _userId,
                          currentPassword: oldCtrl.text,
                          newPassword:     newCtrl.text,
                          newPassword2:    confirmCtrl.text,
                        );
                      }
                      setSheetState(() => isLoading = false);
                      if (!mounted) return;
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message'] ?? '')),
                      );
                    },
                    child: isLoading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(lang.t('save'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccount() {
    final lang     = context.read<LanguageProvider>();
    final passCtrl = TextEditingController();
    bool  isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
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
                Text(lang.t('delete_account'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: Colors.red)),
                const SizedBox(height: 8),
                Text(
                  lang.t('delete_account_confirm'),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                _PassField(ctrl: passCtrl, hint: lang.t('password')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isLoading ? null : () async {
                      if (passCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(lang.t('fill_all_fields'))),
                        );
                        return;
                      }
                      setSheetState(() => isLoading = true);
                      Map<String, dynamic> result;
                      if (_role == 'client') {
                        result = await ApiService.deleteClient(
                          clientId: _userId,
                          password: passCtrl.text,
                        );
                      } else {
                        result = await ApiService.deleteProvider(
                          providerId: _userId,
                          password:   passCtrl.text,
                        );
                      }
                      setSheetState(() => isLoading = false);
                      if (!mounted) return;
                      if (result['success'] == true) {
                        Navigator.pop(sheetCtx);
                        await UserSession.clear();
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const SignInScreen()),
                          (_) => false,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result['message'] ?? '')),
                        );
                        setSheetState(() => isLoading = false);
                      }
                    },
                    child: isLoading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(lang.t('delete_my_account'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();

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

                    // ── Header ─────────────────────────────────────────
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

                    // ── Profile card — tap to edit profile ─────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () async {
                          final updated = await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                          if (updated == true) {
                            _loadUser();
                            // ✅ FIX: Reload UserProvider to refresh photo everywhere
                            if (mounted) await context.read<UserProvider>().load();
                          }
                        },
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
                            // ✅ FIX: Use UserProvider photoPath for the avatar
                            UserAvatar(
                              avatarIndex: user.avatarIndex,
                              photoPath:   user.photoPath,
                              size:        56,
                              showBorder:  false,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.fullName.isNotEmpty ? user.fullName : '—',
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
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _role == 'provider'
                                          ? const Color(0xFF8B5CF6).withOpacity(0.12)
                                          : const Color(0xFF2A5298).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _role == 'provider'
                                          ? lang.t('role_label_provider')
                                          : lang.t('role_label_client'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _role == 'provider'
                                            ? const Color(0xFF8B5CF6)
                                            : const Color(0xFF2A5298),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Completion card (providers only) ───────────
                    if (_role == 'provider')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          onTap: () async {
                            final updated = await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ProviderSetupScreen()));
                            if (updated == true) _loadUser();
                          },
                          child: _ProviderCompletionBanner(userId: _userId),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── Language ───────────────────────────────────────
                    _SectionTitle(title: lang.t('language')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
                        ),
                        child: Column(
                          children: [
                            _LangOption(flag: '🇬🇧', label: 'English',  code: 'en', current: lang.langCode, onTap: () => lang.setLanguage('en')),
                            _Divider(),
                            _LangOption(flag: '🇫🇷', label: 'Français', code: 'fr', current: lang.langCode, onTap: () => lang.setLanguage('fr')),
                            _Divider(),
                            _LangOption(flag: '🇸🇦', label: 'العربية', code: 'ar', current: lang.langCode, onTap: () => lang.setLanguage('ar')),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Notifications ──────────────────────────────────
                    _SectionTitle(title: lang.t('notifications')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
                        ),
                        child: Column(
                          children: [
                            _ToggleRow(icon: Icons.calendar_today_rounded,       iconColor: const Color(0xFF2A5298), label: lang.t('notif_bookings'), value: _notifBookings, onChanged: (v) => setState(() => _notifBookings = v)),
                            _Divider(),
                            _ToggleRow(icon: Icons.chat_bubble_outline_rounded,  iconColor: const Color(0xFF10B981), label: lang.t('notif_messages'), value: _notifMessages, onChanged: (v) => setState(() => _notifMessages = v)),
                            _Divider(),
                            _ToggleRow(icon: Icons.local_offer_outlined,         iconColor: const Color(0xFFF59E0B), label: lang.t('notif_promo'),    value: _notifPromo,    onChanged: (v) => setState(() => _notifPromo    = v)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Account ────────────────────────────────────────
                    _SectionTitle(title: lang.t('account')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
                        ),
                        child: Column(
                          children: [
                            _ActionRow(icon: Icons.lock_outline_rounded,   iconColor: const Color(0xFF8B5CF6), label: lang.t('change_password'), onTap: _showChangePassword),
                            _Divider(),
                            _ActionRow(icon: Icons.delete_outline_rounded, iconColor: Colors.red.shade400,     label: lang.t('delete_account'),  onTap: _showDeleteAccount),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── About ──────────────────────────────────────────
                    _SectionTitle(title: lang.t('about')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
                        ),
                        child: Column(
                          children: [
                            _InfoRow(icon: Icons.info_outline_rounded, iconColor: const Color(0xFF0EA5E9), label: lang.t('app_version'), value: '1.0.0'),
                            _Divider(),
                            _InfoRow(icon: Icons.business_rounded,     iconColor: const Color(0xFF64748B), label: lang.t('made_by'),    value: 'ALOO Team'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Logout button ──────────────────────────────────
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
                          label: Text(lang.t('logout'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.2),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 56, color: Colors.grey.shade100);
}

class _LangOption extends StatelessWidget {
  final String flag, label, code, current;
  final VoidCallback onTap;
  const _LangOption({required this.flag, required this.label, required this.code, required this.current, required this.onTap});

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
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF2A5298), size: 22),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon; final Color iconColor; final String label; final bool value; final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.icon, required this.iconColor, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withOpacity(0.10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: const Color(0xFF2A5298)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon; final Color iconColor; final String label; final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.iconColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withOpacity(0.10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final Color iconColor; final String label, value;
  const _InfoRow({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withOpacity(0.10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
          Text(value, style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
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
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider Completion Banner — shown in Settings for providers
// ─────────────────────────────────────────────────────────────────────────────

class _ProviderCompletionBanner extends StatefulWidget {
  final int userId;
  const _ProviderCompletionBanner({required this.userId});
  @override
  State<_ProviderCompletionBanner> createState() => _ProviderCompletionBannerState();
}

class _ProviderCompletionBannerState extends State<_ProviderCompletionBanner> {
  int _pct = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId == 0) return;
    try {
      final p = await ApiService.getProviderSettings(widget.userId);
      if (!mounted) return;
      setState(() {
        _pct = calcCompletion(
          hasPhoto:     p?['profile_photo'] != null,
          hasBio:       (p?['bio'] ?? '').length >= 10,
          hasSkills:    p?['skills'] != null && (p!['skills'] as String).isNotEmpty && p!['skills'] != '[]',
          hasPortfolio: p?['portfolio'] != null && (p!['portfolio'] as String).isNotEmpty && p!['portfolio'] != '[]',
        );
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang  = context.watch<LanguageProvider>();
    final color = _pct == 100
        ? const Color(0xFF10B981)
        : _pct >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 2.5)),
          child: Center(child: Text('$_pct%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lang.t('profile_completion'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A3A6B))),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _pct / 100, minHeight: 6,
              backgroundColor: Colors.grey.shade100, color: color)),
        ])),
        const SizedBox(width: 12),
        Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 16),
      ]),
    );
  }
}