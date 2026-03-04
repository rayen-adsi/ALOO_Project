import 'package:flutter/material.dart';

enum SignUpRole { client, provider }

class SignUpFlowScreen extends StatefulWidget {
  final SignUpRole? initialRole;

  const SignUpFlowScreen({
    super.key,
    this.initialRole,
  });

  @override
  State<SignUpFlowScreen> createState() => _SignUpFlowScreenState();
}

class _SignUpFlowScreenState extends State<SignUpFlowScreen> {
  late final SignUpRole _role;

  // Provider multi-step
  final PageController _pageCtrl = PageController();
  int _step = 0; // 0 personal, 1 professional

  // Controllers (MVP)
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Professional
  String? _category;
  final _cityCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole ?? SignUpRole.client;
  }

  @override
  void dispose() {
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

  String get _bgAsset =>
      _role == SignUpRole.client
          ? 'assets/images/bg_client.png'
          : 'assets/images/bg_provider.png';

  bool get _isProvider => _role == SignUpRole.provider;

  Future<void> _onBack() async {
    if (_isProvider && _step == 1) {
      await _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _onPrimary() async {
    if (_isProvider) {
      if (_step == 0) {
        // TODO: validate step 1 before going next
        await _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        // TODO: validate + submit provider signup
        // submitProvider();
      }
    } else {
      // TODO: submit client signup
      // submitClient();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Base background
          Positioned.fill(
            child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
          ),

          // Role background (instant)
          Positioned.fill(
            child: Image.asset(_bgAsset, fit: BoxFit.cover),
          ),

          // Light overlay
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

          // Top bar
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
              ],
            ),
          ),

          // Content
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 86, 20, 18),
                child: Column(
                  children: [
                    // Header (changes for provider steps)
                    _HeaderBlock(
                      isProvider: _isProvider,
                      step: _step,
                    ),
                    const SizedBox(height: 18),

                    // Forms
                    Expanded(
                      child: _isProvider
                          ? PageView(
                              controller: _pageCtrl,
                              physics: const NeverScrollableScrollPhysics(),
                              onPageChanged: (i) => setState(() => _step = i),
                              children: [
                                _ProviderPersonalForm(
                                  fullNameCtrl: _fullNameCtrl,
                                  emailCtrl: _emailCtrl,
                                  phoneCtrl: _phoneCtrl,
                                  passCtrl: _passCtrl,
                                  pass2Ctrl: _pass2Ctrl,
                                ),
                                _ProviderProfessionalForm(
                                  category: _category,
                                  onCategoryChanged: (v) =>
                                      setState(() => _category = v),
                                  cityCtrl: _cityCtrl,
                                  addressCtrl: _addressCtrl,
                                  bioCtrl: _bioCtrl,
                                ),
                              ],
                            )
                          : _ClientForm(
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
                    _PrimaryBottomButton(
                      label: _isProvider
                          ? (_step == 0 ? "Suivant" : "Créer mon compte")
                          : "Créer mon compte",
                      icon: _isProvider && _step == 0
                          ? Icons.arrow_forward_rounded
                          : null,
                      onPressed: _onPrimary,
                    ),

                    const SizedBox(height: 14),

                    _BottomLogin(onTapLogin: () => Navigator.pop(context)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== HEADER =====================

class _HeaderBlock extends StatelessWidget {
  final bool isProvider;
  final int step;

  const _HeaderBlock({
    required this.isProvider,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final title = isProvider
        ? (step == 0 ? "Informations personnelles" : "Informations professionnelles")
        : "Create Account";

    final subtitle = isProvider
        ? (step == 0
            ? "Renseignez vos informations de base"
            : "Décrivez votre activité et votre zone")
        : "Sign up to start using ALOO";

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

// ===================== CLIENT FORM (1 PAGE) =====================

class _ClientForm extends StatelessWidget {
  final TextEditingController fullNameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passCtrl;
  final TextEditingController pass2Ctrl;
  final TextEditingController addressCtrl;

  const _ClientForm({
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          _InputBox(
            controller: fullNameCtrl,
            hint: "Nom complet",
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),

          _InputBox(
            controller: emailCtrl,
            hint: "Email",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),

          _InputBox(
            controller: phoneCtrl,
            hint: "Téléphone",
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),

          _InputBox(
            controller: passCtrl,
            hint: "Mot de passe",
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 14),

          _InputBox(
            controller: pass2Ctrl,
            hint: "Confirmer mot de passe",
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 14),

          _InputBox(
            controller: addressCtrl,
            hint: "Adresse",
            icon: Icons.location_on_outlined,
          ),
        ],
      ),
    );
  }
}

// ===================== PROVIDER STEP 1 =====================

class _ProviderPersonalForm extends StatelessWidget {
  final TextEditingController fullNameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passCtrl;
  final TextEditingController pass2Ctrl;

  const _ProviderPersonalForm({
    required this.fullNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passCtrl,
    required this.pass2Ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          _InputBox(
            controller: fullNameCtrl,
            hint: "Nom complet",
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),

          _InputBox(
            controller: emailCtrl,
            hint: "Email",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),

          _InputBox(
            controller: phoneCtrl,
            hint: "Téléphone",
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),

          _InputBox(
            controller: passCtrl,
            hint: "Mot de passe",
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 14),

          _InputBox(
            controller: pass2Ctrl,
            hint: "Confirmez mot de passe",
            icon: Icons.lock_outline,
            isPassword: true,
          ),
        ],
      ),
    );
  }
}

// ===================== PROVIDER STEP 2 =====================

class _ProviderProfessionalForm extends StatelessWidget {
  final String? category;
  final ValueChanged<String?> onCategoryChanged;
  final TextEditingController cityCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController bioCtrl;

  const _ProviderProfessionalForm({
    required this.category,
    required this.onCategoryChanged,
    required this.cityCtrl,
    required this.addressCtrl,
    required this.bioCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          _DropdownBox(
            value: category,
            hint: "Catégorie",
            icon: Icons.work_outline,
            items: const [
              "Plombier",
              "Électricien",
              "Mécanicien",
              "Femme de ménage",
              "Professeur",
              "Développeur",
            ],
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 14),

          _InputBox(
            controller: cityCtrl,
            hint: "Ville / Zone",
            icon: Icons.location_city_outlined,
          ),
          const SizedBox(height: 14),

          _InputBox(
            controller: addressCtrl,
            hint: "Adresse",
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 14),

          _InputBox(
            controller: bioCtrl,
            hint: "Description (ex: 5 ans d'expérience...)",
            icon: Icons.description_outlined,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

// ===================== INPUT BOX =====================

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
    final isMultiLine = widget.maxLines > 1;

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
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(widget.icon, color: Colors.grey.shade600),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey.shade600,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.92),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: isMultiLine ? 16 : 16,
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
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.6),
        ),
      ),
    );
  }
}

// ===================== DROPDOWN BOX =====================

class _DropdownBox extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownBox({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.white.withOpacity(0.92),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.6),
        ),
      ),
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
      icon: const Icon(Icons.expand_more_rounded),
    );
  }
}

// ===================== PRIMARY BUTTON (BOTTOM) =====================

class _PrimaryBottomButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const _PrimaryBottomButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: Colors.black.withOpacity(0.20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 10),
              Icon(icon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

// ===================== BOTTOM LOGIN =====================

class _BottomLogin extends StatelessWidget {
  final VoidCallback onTapLogin;

  const _BottomLogin({required this.onTapLogin});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Already have an account? ",
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
        GestureDetector(
          onTap: onTapLogin,
          child: const Text(
            "Log In",
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}