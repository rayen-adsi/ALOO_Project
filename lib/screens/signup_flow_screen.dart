// lib/screens/signup_flow_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/l10n/language_provider.dart';
import '../services/api_services.dart';
import '../screens/widgets/lang_toggle_button.dart';
import 'sign_in_screen.dart';

enum SignUpRole { client, provider }

class SignUpFlowScreen extends StatefulWidget {
  final SignUpRole? initialRole;

  const SignUpFlowScreen({super.key, this.initialRole});

  @override
  State<SignUpFlowScreen> createState() => _SignUpFlowScreenState();
}

class _SignUpFlowScreenState extends State<SignUpFlowScreen>
    with SingleTickerProviderStateMixin {
  late final SignUpRole _role;

  final PageController _pageCtrl = PageController();
  int _step = 0;
  bool _isLoading = false;

  late final AnimationController _animCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  final _fullNameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _pass2Ctrl    = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _bioCtrl      = TextEditingController();

  String? _category;

  // Category keys for translation (display label)
  static const List<String> _categoryKeys = [
    'cat_plumber',
    'cat_electrician',
    'cat_mechanic',
    'cat_cleaner',
    'cat_tutor',
    'cat_developer',
    'cat_home_repair',
  ];

  // Exact French values matching backend VALID_CATEGORIES
  static const List<String> _categoryBackendValues = [
    'Plombier',
    'Électricien',
    'Mécanicien',
    'Femme de ménage',
    'Professeur',
    'Développeur',
    'Réparation domicile',
  ];

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole ?? SignUpRole.client;

    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeIn)));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _pageCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  bool get _isProvider => _role == SignUpRole.provider;

  String get _bgAsset => _role == SignUpRole.client
      ? 'assets/images/bg_client.png'
      : 'assets/images/bg_provider.png';

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onBack() async {
    if (_isProvider && _step == 1) {
      await _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic);
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _onPrimary() async {
    if (_isLoading) return;
    if (_isProvider) {
      _step == 0
          ? await _handleProviderStep1()
          : await _handleProviderStep2();
    } else {
      await _handleClientSignup();
    }
  }

  Future<void> _handleClientSignup() async {
    final lang = context.read<LanguageProvider>();
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.signupClient(
        fullName:  _fullNameCtrl.text.trim(),
        email:     _emailCtrl.text.trim(),
        phone:     _phoneCtrl.text.trim(),
        password:  _passCtrl.text,
        password2: _pass2Ctrl.text,
        address:   _addressCtrl.text.trim(),
      );
      if (!mounted) return;
      _showMessage(result['message']);
      if (result['success'] == true) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const SignInScreen()));
      }
    } catch (_) {
      if (mounted) _showMessage(lang.t('connection_error'));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleProviderStep1() async {
    final lang = context.read<LanguageProvider>();
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.signupProviderStep1(
        fullName:  _fullNameCtrl.text.trim(),
        email:     _emailCtrl.text.trim(),
        phone:     _phoneCtrl.text.trim(),
        password:  _passCtrl.text,
        password2: _pass2Ctrl.text,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        await _pageCtrl.nextPage(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic);
      } else {
        _showMessage(result['message']);
      }
    } catch (_) {
      if (mounted) _showMessage(lang.t('connection_error'));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleProviderStep2() async {
    final lang = context.read<LanguageProvider>();
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.signupProviderStep2(
        fullName: _fullNameCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
        phone:    _phoneCtrl.text.trim(),
        password: _passCtrl.text,
        category: _category ?? '',
        city:     _cityCtrl.text.trim(),
        address:  _addressCtrl.text.trim(),
        bio:      _bioCtrl.text.trim(),
      );
      if (!mounted) return;
      _showMessage(result['message']);
      if (result['success'] == true) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const SignInScreen()));
      }
    } catch (_) {
      if (mounted) _showMessage(lang.t('connection_error'));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang       = context.watch<LanguageProvider>();
    final topPadding = MediaQuery.of(context).padding.top;

    final String headerTitle;
    final String headerSub;

    if (_isProvider) {
      headerTitle = _step == 0
          ? lang.t('personal_info')
          : lang.t('professional_info');
      headerSub = _step == 0
          ? lang.t('personal_info_sub')
          : lang.t('professional_info_sub');
    } else {
      headerTitle = lang.t('create_account_title');
      headerSub   = lang.t('create_account_sub');
    }

    final String primaryBtnLabel = _isProvider
        ? (_step == 0 ? lang.t('next') : lang.t('finish_signup'))
        : lang.t('finish_signup');

    // Translated categories for dropdown
    final List<String> categories =
        _categoryKeys.map((k) => lang.t(k)).toList();

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // Backgrounds
            Positioned.fill(
                child: Image.asset('assets/images/bg.png',
                    fit: BoxFit.cover)),
            Positioned.fill(
                child: Image.asset(_bgAsset, fit: BoxFit.cover)),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.22),
                      Colors.white.withOpacity(0.50),
                    ],
                  ),
                ),
              ),
            ),

            // Top bar — exactly as original (back arrow + centered logo)
            Positioned(
              left: 14,
              right: 14,
              top: topPadding + 8,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  Image.asset('assets/images/aloo_logo.png', height: 28),
                  const Spacer(),
                  // invisible spacer to keep logo centered
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Lang toggle — floating top-right, independent of top bar
            Positioned(
              top: topPadding + 14,
              right: 14,
              child: const LangToggleButton(iconColor: Color(0xFF2A4870)),
            ),

            // Content
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 86, 20, 18),
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            Text(
                              headerTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              headerSub,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Expanded(
                        child: SlideTransition(
                          position: _slideAnim,
                          child: FadeTransition(
                            opacity: _fadeAnim,
                            child: Column(
                              children: [
                                Expanded(
                                  child: _isProvider
                                      ? PageView(
                                          controller: _pageCtrl,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          onPageChanged: (i) =>
                                              setState(() =>
                                                  _step = i),
                                          children: [
                                            _PersonalForm(
                                              lang: lang,
                                              fullNameCtrl:
                                                  _fullNameCtrl,
                                              emailCtrl: _emailCtrl,
                                              phoneCtrl: _phoneCtrl,
                                              passCtrl: _passCtrl,
                                              pass2Ctrl: _pass2Ctrl,
                                            ),
                                            _ProfessionalForm(
                                              lang: lang,
                                              category: _category,
                                              categories: categories,
                                              categoryKeys: _categoryBackendValues, // send French to backend
                                              onCategoryChanged:
                                                  (v) => setState(
                                                      () =>
                                                          _category =
                                                              v),
                                              cityCtrl: _cityCtrl,
                                              addressCtrl:
                                                  _addressCtrl,
                                              bioCtrl: _bioCtrl,
                                            ),
                                          ],
                                        )
                                      : _ClientFullForm(
                                          lang: lang,
                                          fullNameCtrl: _fullNameCtrl,
                                          emailCtrl: _emailCtrl,
                                          phoneCtrl: _phoneCtrl,
                                          passCtrl: _passCtrl,
                                          pass2Ctrl: _pass2Ctrl,
                                          addressCtrl: _addressCtrl,
                                        ),
                                ),

                                const SizedBox(height: 14),

                                // Primary button
                                SizedBox(
                                  height: 56,
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? () {}
                                        : _onPrimary,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF3B82F6),
                                      foregroundColor: Colors.white,
                                      elevation: 6,
                                      shadowColor: Colors.black
                                          .withOpacity(0.20),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                            children: [
                                              Text(
                                                primaryBtnLabel,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight.w900,
                                                ),
                                              ),
                                              if (_isProvider &&
                                                  _step == 0) ...[
                                                const SizedBox(
                                                    width: 10),
                                                const Icon(
                                                  Icons
                                                      .arrow_forward_rounded,
                                                  size: 20,
                                                ),
                                              ],
                                            ],
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Already have account
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      lang.t('already_have_account'),
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          Navigator.pop(context),
                                      child: Text(
                                        lang.t('log_in'),
                                        style: const TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
// Forms
// ─────────────────────────────────────────────────────────────────────────────

class _ClientFullForm extends StatelessWidget {
  final LanguageProvider lang;
  final TextEditingController fullNameCtrl, emailCtrl, phoneCtrl,
      passCtrl, pass2Ctrl, addressCtrl;

  const _ClientFullForm({
    required this.lang,
    required this.fullNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passCtrl,
    required this.pass2Ctrl,
    required this.addressCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(children: [
        _InputBox(controller: fullNameCtrl, hint: lang.t('full_name'),        icon: Icons.person_outline),
        const SizedBox(height: 14),
        _InputBox(controller: emailCtrl,    hint: lang.t('email'),            icon: Icons.email_outlined,    keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _InputBox(controller: phoneCtrl,    hint: lang.t('phone'),            icon: Icons.phone_outlined,    keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        _InputBox(controller: passCtrl,     hint: lang.t('password'),         icon: Icons.lock_outline,      isPassword: true),
        const SizedBox(height: 14),
        _InputBox(controller: pass2Ctrl,    hint: lang.t('confirm_password'), icon: Icons.lock_outline,      isPassword: true),
        const SizedBox(height: 14),
        _InputBox(controller: addressCtrl,  hint: lang.t('address'),          icon: Icons.location_on_outlined),
      ]),
    );
  }
}

class _PersonalForm extends StatelessWidget {
  final LanguageProvider lang;
  final TextEditingController fullNameCtrl, emailCtrl, phoneCtrl,
      passCtrl, pass2Ctrl;

  const _PersonalForm({
    required this.lang,
    required this.fullNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passCtrl,
    required this.pass2Ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(children: [
        _InputBox(controller: fullNameCtrl, hint: lang.t('full_name'),        icon: Icons.person_outline),
        const SizedBox(height: 14),
        _InputBox(controller: emailCtrl,    hint: lang.t('email'),            icon: Icons.email_outlined,    keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _InputBox(controller: phoneCtrl,    hint: lang.t('phone'),            icon: Icons.phone_outlined,    keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        _InputBox(controller: passCtrl,     hint: lang.t('password'),         icon: Icons.lock_outline,      isPassword: true),
        const SizedBox(height: 14),
        _InputBox(controller: pass2Ctrl,    hint: lang.t('confirm_password'), icon: Icons.lock_outline,      isPassword: true),
      ]),
    );
  }
}

class _ProfessionalForm extends StatelessWidget {
  final LanguageProvider lang;
  final String? category;
  final List<String> categories;
  final List<String> categoryKeys;
  final ValueChanged<String?> onCategoryChanged;
  final TextEditingController cityCtrl, addressCtrl, bioCtrl;

  const _ProfessionalForm({
    required this.lang,
    required this.category,
    required this.categories,
    required this.categoryKeys,
    required this.onCategoryChanged,
    required this.cityCtrl,
    required this.addressCtrl,
    required this.bioCtrl,
  });

  static const Map<String, IconData> _categoryIcons = {
    'Plombier':            Icons.water_drop_outlined,
    'Électricien':         Icons.bolt_outlined,
    'Mécanicien':          Icons.build_outlined,
    'Femme de ménage':     Icons.cleaning_services_outlined,
    'Professeur':          Icons.school_outlined,
    'Développeur':         Icons.code_outlined,
    'Réparation domicile': Icons.home_repair_service_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final selectedLabel = category != null
        ? categories[categoryKeys.indexOf(category!)]
        : null;
    final selectedIcon = category != null
        ? (_categoryIcons[category!] ?? Icons.work_outline)
        : null;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PrettyDropdown(
            hint: lang.t('category'),
            selectedLabel: selectedLabel,
            selectedIcon: selectedIcon,
            items: List.generate(categoryKeys.length, (i) => _DropdownItem(
              key: categoryKeys[i],
              label: categories[i],
              icon: _categoryIcons[categoryKeys[i]] ?? Icons.work_outline,
            )),
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 14),
          _InputBox(controller: cityCtrl,    hint: lang.t('city'),    icon: Icons.location_city_outlined),
          const SizedBox(height: 14),
          _InputBox(controller: addressCtrl, hint: lang.t('address'), icon: Icons.location_on_outlined),
          const SizedBox(height: 14),
          _InputBox(controller: bioCtrl,     hint: lang.t('bio'),     icon: Icons.description_outlined, maxLines: 3),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pretty Dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _DropdownItem {
  final String key;
  final String label;
  final IconData icon;
  const _DropdownItem({required this.key, required this.label, required this.icon});
}

class _PrettyDropdown extends StatefulWidget {
  final String hint;
  final String? selectedLabel;
  final IconData? selectedIcon;
  final List<_DropdownItem> items;
  final ValueChanged<String?> onChanged;

  const _PrettyDropdown({
    required this.hint,
    required this.selectedLabel,
    required this.selectedIcon,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_PrettyDropdown> createState() => _PrettyDropdownState();
}

class _PrettyDropdownState extends State<_PrettyDropdown>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _rotateAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    _isOpen ? _ctrl.forward() : _ctrl.reverse();
  }

  void _select(_DropdownItem item) {
    widget.onChanged(item.key);
    setState(() => _isOpen = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = widget.selectedLabel != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Trigger button ──────────────────────────────────────
        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: _isOpen
                  ? const BorderRadius.vertical(top: Radius.circular(14))
                  : BorderRadius.circular(14),
              border: Border.all(
                color: _isOpen
                    ? const Color(0xFF3B82F6)
                    : Colors.grey.shade300,
                width: _isOpen ? 1.6 : 1.0,
              ),
              boxShadow: _isOpen
                  ? [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // Icon
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    hasSelection ? widget.selectedIcon : Icons.work_outline,
                    key: ValueKey(widget.selectedIcon),
                    color: hasSelection
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade500,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Label
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      widget.selectedLabel ?? widget.hint,
                      key: ValueKey(widget.selectedLabel),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: hasSelection
                            ? const Color(0xFF0F172A)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                // Chevron
                RotationTransition(
                  turns: _rotateAnim,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _isOpen
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade500,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Dropdown list ───────────────────────────────────────
        FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: _isOpen
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(14)),
                      border: Border.all(
                          color: const Color(0xFF3B82F6), width: 1.6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: widget.items.map((item) {
                        final isSelected =
                            item.label == widget.selectedLabel;
                        return _DropdownRow(
                          item: item,
                          isSelected: isSelected,
                          onTap: () => _select(item),
                        );
                      }).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _DropdownRow extends StatefulWidget {
  final _DropdownItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _DropdownRow({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DropdownRow> createState() => _DropdownRowState();
}

class _DropdownRowState extends State<_DropdownRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) => setState(() => _hovered = false),
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? const Color(0xFFEFF6FF)
              : _hovered
                  ? const Color(0xFFF8FAFC)
                  : Colors.transparent,
          border: Border(
            top: BorderSide(color: Colors.grey.shade100, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Icon bubble
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? const Color(0xFFDBEAFE)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.item.icon,
                size: 17,
                color: widget.isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.item.label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: widget.isSelected
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: widget.isSelected
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF0F172A),
                ),
              ),
            ),
            if (widget.isSelected)
              const Icon(Icons.check_rounded,
                  color: Color(0xFF2563EB), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input Box (unchanged logic, kept here for self-containment)
// ─────────────────────────────────────────────────────────────────────────────

class _InputBox extends StatefulWidget {
  final TextEditingController? controller;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final int maxLines;

  const _InputBox({
    this.controller,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  State<_InputBox> createState() => _InputBoxState();
}

class _InputBoxState extends State<_InputBox> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.isPassword ? _obscure : false,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600),
        prefixIcon:
            Icon(widget.icon, color: Colors.grey.shade600),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey.shade600,
                ),
                onPressed: () =>
                    setState(() => _obscure = !_obscure),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.92),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: widget.maxLines > 1 ? 16 : 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: Color(0xFF3B82F6), width: 1.6),
        ),
      ),
    );
  }
}