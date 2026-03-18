// lib/screens/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../core/storage/user_session.dart';
import '../services/api_services.dart';
import '../core/user_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Avatar constants — 15 PNG files in assets/images/avatars/
// ─────────────────────────────────────────────────────────────────────────────

const int kAvatarCount = 15;

String avatarAssetPath(int index) {
  final n = (index.clamp(0, kAvatarCount - 1) + 1).toString().padLeft(2, '0');
  return 'assets/images/avatars/avatar_$n.png';
}

// ─────────────────────────────────────────────────────────────────────────────
// UserAvatar — shows real photo OR avatar PNG
// ─────────────────────────────────────────────────────────────────────────────

class UserAvatar extends StatelessWidget {
  final int           avatarIndex;
  final double        size;
  final VoidCallback? onTap;
  final bool          showBorder;
  final String?       photoPath;

  const UserAvatar({
    super.key,
    required this.avatarIndex,
    this.size       = 40,
    this.onTap,
    this.showBorder = false,
    this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (photoPath != null && photoPath!.isNotEmpty) {
      if (photoPath!.startsWith('http')) {
        image = Image.network(photoPath!, width: size, height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarWidget());
      } else {
        image = Image.file(File(photoPath!), width: size, height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarWidget());
      }
    } else {
      image = _avatarWidget();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: showBorder
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: size * 0.06),
                boxShadow: [BoxShadow(
                  color:      Colors.black.withOpacity(0.20),
                  blurRadius: 10,
                  offset:     const Offset(0, 3),
                )],
              )
            : null,
        child: ClipOval(child: image),
      ),
    );
  }

  Widget _avatarWidget() => Image.asset(
    avatarAssetPath(avatarIndex),
    width: size, height: size, fit: BoxFit.cover,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Profile Screen
// ─────────────────────────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  String  _fullName     = '';
  String  _email        = '';
  String  _role         = 'client';
  int     _userId       = 0;
  int     _avatarIndex  = 0;
  int     _tempAvatar   = 0;
  String? _photoPath;
  String? _networkPhoto;

  final _picker      = ImagePicker();
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _bioCtrl     = TextEditingController();

  bool _loading    = true;
  bool _saving     = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    for (final c in [_nameCtrl, _phoneCtrl, _addressCtrl, _cityCtrl, _bioCtrl]) {
      c.addListener(() => setState(() => _hasChanges = true));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final session   = await UserSession.load();
    final role      = session['role']         ?? 'client';
    final userId    = session['id']           ?? 0;
    final avatarIdx = session['avatar_index'] ?? 0;

    Map<String, dynamic>? profile;
    try {
      profile = role == 'client'
          ? await ApiService.getClient(userId)
          : await ApiService.getProviderSettings(userId);
    } catch (_) {}

    if (!mounted) return;

    // ✅ Get avatar_index from backend if available, fallback to local
    final backendAvatar = (profile?['avatar_index'] as int?) ?? avatarIdx;

    setState(() {
      _fullName     = session['full_name'] ?? '';
      _email        = session['email']     ?? '';
      _role         = role;
      _userId       = userId;
      _avatarIndex  = (backendAvatar as int).clamp(0, kAvatarCount - 1);
      _tempAvatar   = _avatarIndex;
      _networkPhoto = profile?['profile_photo'] as String?;

      _nameCtrl.text    = profile?['full_name'] ?? _fullName;
      _phoneCtrl.text   = profile?['phone']     ?? '';
      _addressCtrl.text = profile?['address']   ?? '';
      _cityCtrl.text    = profile?['city']       ?? '';
      _bioCtrl.text     = profile?['bio']        ?? '';
      _loading          = false;
      _hasChanges       = false;
    });
  }

  Future<void> _save() async {
    final lang = context.read<LanguageProvider>();
    if (_nameCtrl.text.trim().isEmpty) {
      _snack(lang.t('fill_all_fields'));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_photoPath != null) {
        await ApiService.uploadProfilePhoto(
          userId:   _userId,
          role:     _role,
          filePath: _photoPath!,
        );
      } else if (_networkPhoto == null) {
        await ApiService.deleteProfilePhoto(userId: _userId, role: _role);
      }

      // ✅ Save profile data INCLUDING avatar_index to backend
      if (_role == 'client') {
        await ApiService.updateClient(_userId, {
          'full_name':    _nameCtrl.text.trim(),
          'phone':        _phoneCtrl.text.trim(),
          'address':      _addressCtrl.text.trim(),
          'avatar_index': _tempAvatar,
        });
      } else {
        await ApiService.updateProviderProfile(_userId, {
          'bio':          _bioCtrl.text.trim(),
          'city':         _cityCtrl.text.trim(),
          'address':      _addressCtrl.text.trim(),
          'avatar_index': _tempAvatar,
        });
      }

      await UserSession.save(
        id:          _userId,
        fullName:    _nameCtrl.text.trim(),
        email:       _email,
        role:        _role,
        avatarIndex: _tempAvatar,
      );

      if (!mounted) return;
      // Update global UserProvider so all pages refresh instantly
      context.read<UserProvider>().update(
        fullName:    _nameCtrl.text.trim(),
        avatarIndex: _tempAvatar,
        photoPath:   _photoPath ?? _networkPhoto,
      );
      setState(() {
        _saving      = false;
        _hasChanges  = false;
        _avatarIndex = _tempAvatar;
      });
      _snack(lang.t('profile_updated'));
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(lang.t('connection_error'));
      }
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source, imageQuality: 85, maxWidth: 600,
      );
      if (picked != null && mounted) {
        setState(() {
          _photoPath    = picked.path;
          _networkPhoto = null;
          _hasChanges   = true;
        });
      }
    } catch (_) {}
  }

  void _showPhotoOptions() {
    final lang = context.read<LanguageProvider>();
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 20),
            Text(lang.t('profile_photo'),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: Color(0xFF1A3A6B))),
            const SizedBox(height: 20),
            _PhotoOption(
              icon:  Icons.camera_alt_rounded,
              label: lang.t('take_photo'),
              color: const Color(0xFF2A5298),
              onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.camera); },
            ),
            const SizedBox(height: 12),
            _PhotoOption(
              icon:  Icons.photo_library_rounded,
              label: lang.t('choose_from_gallery'),
              color: const Color(0xFF2A5298),
              onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.gallery); },
            ),
            const SizedBox(height: 12),
            _PhotoOption(
              icon:  Icons.face_retouching_natural_rounded,
              label: lang.t('choose_avatar'),
              color: const Color(0xFF7C3AED),
              onTap: () { Navigator.pop(context); _showAvatarPicker(); },
            ),
            if (_photoPath != null || _networkPhoto != null) ...[
              const SizedBox(height: 12),
              _PhotoOption(
                icon:  Icons.delete_outline_rounded,
                label: 'Remove photo',
                color: Colors.red.shade400,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _photoPath    = null;
                    _networkPhoto = null;
                    _hasChanges   = true;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AvatarPickerSheet(
        current:  _tempAvatar,
        onSelect: (i) {
          setState(() { _tempAvatar = i; _hasChanges = true; });
          Navigator.pop(context);
        },
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
                child: Image.asset('assets/images/bg.png', fit: BoxFit.cover)),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.80),
                      Colors.white.withOpacity(0.97),
                    ],
                  ),
                ),
              ),
            ),

            if (_loading)
              const Center(child: CircularProgressIndicator(
                  color: Color(0xFF2A5298), strokeWidth: 2.5))
            else
              Column(
                children: [

                  // ── Top bar ────────────────────────────────────
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Color(0xFF1A3A6B), size: 20),
                          ),
                          Expanded(
                            child: Text(lang.t('edit_profile'),
                              style: const TextStyle(
                                fontSize:   20,
                                fontWeight: FontWeight.w900,
                                color:      Color(0xFF1A3A6B),
                              )),
                          ),
                          if (_hasChanges)
                            TextButton(
                              onPressed: _saving ? null : _save,
                              child: Text(lang.t('save'),
                                style: const TextStyle(
                                  fontSize:   15,
                                  fontWeight: FontWeight.w800,
                                  color:      Color(0xFF2A5298),
                                )),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Scrollable content ─────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ── Photo card ─────────────────────────
                          _Card(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _showPhotoOptions,
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      UserAvatar(
                                        avatarIndex: _tempAvatar,
                                        photoPath:   _photoPath ?? _networkPhoto,
                                        size:        100,
                                      ),
                                      Container(
                                        width: 30, height: 30,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF2A5298),
                                        ),
                                        child: const Icon(Icons.edit_rounded,
                                            color: Colors.white, size: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _nameCtrl.text.isNotEmpty
                                      ? _nameCtrl.text : _fullName,
                                  style: const TextStyle(
                                    fontSize:   16,
                                    fontWeight: FontWeight.w700,
                                    color:      Color(0xFF1A3A6B),
                                  ),
                                ),
                                Text(_email,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500)),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showPhotoOptions,
                                        icon: const Icon(
                                            Icons.add_a_photo_rounded,
                                            size: 16),
                                        label: Text(lang.t('upload_photo'),
                                            style: const TextStyle(
                                                fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF2A5298),
                                          side: const BorderSide(
                                              color: Color(0xFF2A5298),
                                              width: 1.5),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showAvatarPicker,
                                        icon: const Icon(
                                            Icons
                                                .face_retouching_natural_rounded,
                                            size: 16),
                                        label: Text(lang.t('choose_avatar'),
                                            style: const TextStyle(
                                                fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF7C3AED),
                                          side: const BorderSide(
                                              color: Color(0xFF7C3AED),
                                              width: 1.5),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Personal info ──────────────────────
                          _SectionLabel(label: lang.t('personal_info')),
                          _EditField(
                            ctrl:  _nameCtrl,
                            label: lang.t('name_label'),
                            icon:  Icons.person_rounded,
                            color: const Color(0xFF2A5298),
                          ),
                          _ReadField(
                            value: _email,
                            label: lang.t('email'),
                            icon:  Icons.email_rounded,
                          ),
                          _EditField(
                            ctrl:     _phoneCtrl,
                            label:    lang.t('phone_label'),
                            icon:     Icons.phone_rounded,
                            color:    const Color(0xFF10B981),
                            keyboard: TextInputType.phone,
                          ),
                          _EditField(
                            ctrl:  _addressCtrl,
                            label: lang.t('address_label'),
                            icon:  Icons.location_on_rounded,
                            color: const Color(0xFFEF4444),
                          ),

                          // ── Provider only ──────────────────────
                          if (_role == 'provider') ...[
                            const SizedBox(height: 24),
                            _SectionLabel(
                                label: lang.t('professional_info')),
                            _EditField(
                              ctrl:  _cityCtrl,
                              label: lang.t('city_label'),
                              icon:  Icons.location_city_rounded,
                              color: const Color(0xFF8B5CF6),
                            ),
                            _EditField(
                              ctrl:     _bioCtrl,
                              label:    lang.t('bio_label'),
                              icon:     Icons.description_rounded,
                              color:    const Color(0xFFF59E0B),
                              maxLines: 4,
                            ),
                          ],

                          const SizedBox(height: 28),

                          // ── Save button ────────────────────────
                          SizedBox(
                            width:  double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A3A6B),
                                elevation:       0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16)),
                              ),
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      width: 22, height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color:       Colors.white))
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                            size:  20),
                                        const SizedBox(width: 8),
                                        Text(
                                          lang.t('save_changes'),
                                          style: const TextStyle(
                                            fontSize:   16,
                                            fontWeight: FontWeight.w700,
                                            color:      Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar Picker Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarPickerSheet extends StatefulWidget {
  final int               current;
  final ValueChanged<int> onSelect;
  const _AvatarPickerSheet({required this.current, required this.onSelect});

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Text(lang.t('choose_avatar'),
            style: const TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.w800,
              color:      Color(0xFF1A3A6B),
            )),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap:  true,
            physics:     const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:   4,
              crossAxisSpacing: 12,
              mainAxisSpacing:  12,
              childAspectRatio: 1,
            ),
            itemCount: kAvatarCount,
            itemBuilder: (_, i) {
              final isSelected = _selected == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _selected = i);
                  Future.delayed(const Duration(milliseconds: 180), () {
                    widget.onSelect(i);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: const Color(0xFF2A5298), width: 3)
                        : Border.all(
                            color: Colors.transparent, width: 3),
                    boxShadow: isSelected
                        ? [const BoxShadow(
                            color:      Color(0x402A5298),
                            blurRadius: 12,
                            offset:     Offset(0, 4),
                          )]
                        : [],
                  ),
                  child: UserAvatar(avatarIndex: i),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width:   double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color:      Colors.black.withOpacity(0.06),
          blurRadius: 16,
          offset:     const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 10),
    child: Row(
      children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(
            color:        const Color(0xFF2A5298),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize:      11,
            fontWeight:    FontWeight.w800,
            color:         Color(0xFF2A5298),
            letterSpacing: 1.2,
          ),
        ),
      ],
    ),
  );
}

// ── Editable field with focus animation ───────────────────────────────────

class _EditField extends StatefulWidget {
  final TextEditingController ctrl;
  final String                label;
  final IconData              icon;
  final Color                 color;
  final TextInputType         keyboard;
  final int                   maxLines;

  const _EditField({
    required this.ctrl,
    required this.label,
    required this.icon,
    required this.color,
    this.keyboard = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  State<_EditField> createState() => _EditFieldState();
}

class _EditFieldState extends State<_EditField> {
  final _focus  = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() =>
        setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin:   const EdgeInsets.symmetric(vertical: 6),
      padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _focused
            ? widget.color.withOpacity(0.04)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? widget.color.withOpacity(0.5)
              : Colors.grey.shade200,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: widget.maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(
                top: widget.maxLines > 1 ? 14 : 0),
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _focused
                  ? widget.color.withOpacity(0.12)
                  : widget.color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.icon,
              color: _focused
                  ? widget.color
                  : widget.color.withOpacity(0.6),
              size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller:   widget.ctrl,
              focusNode:    _focus,
              keyboardType: widget.keyboard,
              maxLines:     widget.maxLines,
              style: const TextStyle(
                fontSize:   15.5,
                fontWeight: FontWeight.w600,
                color:      Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                labelText:  widget.label,
                labelStyle: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  color:      _focused
                      ? widget.color
                      : Colors.grey.shade400,
                ),
                floatingLabelStyle: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w700,
                  color:      widget.color,
                ),
                border:         InputBorder.none,
                enabledBorder:  InputBorder.none,
                focusedBorder:  InputBorder.none,
                isDense:        true,
                contentPadding: const EdgeInsets.only(
                    bottom: 6, top: 2),
              ),
            ),
          ),
          if (widget.maxLines == 1)
            Icon(
              _focused
                  ? Icons.edit_rounded
                  : Icons.chevron_right_rounded,
              color: _focused
                  ? widget.color.withOpacity(0.5)
                  : Colors.grey.shade300,
              size: 18,
            ),
        ],
      ),
    );
  }
}

// ── Read-only field ────────────────────────────────────────────────────────

class _ReadField extends StatelessWidget {
  final String   value;
  final String   label;
  final IconData icon;

  const _ReadField({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: Colors.grey.shade400, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize:      11.5,
                    fontWeight:    FontWeight.w600,
                    color:         Colors.grey.shade400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.w600,
                    color:      value.isNotEmpty
                        ? const Color(0xFF64748B)
                        : Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded,
                    color: Colors.grey.shade400, size: 12),
                const SizedBox(width: 4),
                Text('Fixed',
                  style: TextStyle(
                    fontSize:   10,
                    fontWeight: FontWeight.w700,
                    color:      Colors.grey.shade400,
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo option row
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoOption extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _PhotoOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: color.withOpacity(0.20), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:  color.withOpacity(0.12),
                shape:  BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize:   15,
                fontWeight: FontWeight.w600,
                color:      color,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }
}