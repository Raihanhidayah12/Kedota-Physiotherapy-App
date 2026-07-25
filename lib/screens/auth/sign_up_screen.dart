import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/google_logo_icon.dart';
import '../../widgets/language_button.dart';
import '../../widgets/custom_bottom_sheet.dart';
import 'otp_verification_screen.dart';
import 'sign_in_screen.dart';

String? registeredPinValue;
String? registeredPhoneNumber;
String? registeredUserName;
String? registeredUserEmail;
String? registeredUserGender;
DateTime? registeredBirthDate;

enum SignUpStep { phone, profile, pin, success }

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  SignUpStep _currentStep = SignUpStep.phone;
  bool _isSubmitting = false;
  bool _showPin = false;
  bool _showConfirmPin = false;
  DateTime? _birthDate;
  String? _selectedGender;
  String _signupMethod = 'phone';
  String? _profileNoticeProvider;

  bool _isValidIndonesianPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;

    if (digits.startsWith('62')) {
      final mobile = digits.substring(2);
      return mobile.length >= 10 &&
          mobile.length <= 12 &&
          (mobile.startsWith('8') || mobile.startsWith('9'));
    }

    if (digits.startsWith('0')) {
      return digits.length >= 11 &&
          digits.length <= 13 &&
          (digits.startsWith('08') || digits.startsWith('09'));
    }

    return digits.length >= 10 &&
        digits.length <= 12 &&
        (digits.startsWith('8') || digits.startsWith('9'));
  }

  String _normalizePhoneNumber(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('62')) {
      return '+$digits';
    }

    if (digits.startsWith('0')) {
      return '+62${digits.substring(1)}';
    }

    if (digits.startsWith('8')) {
      return '+62$digits';
    }

    return '+62$digits';
  }

  String _hashPin(String input) {
    var hash = 0x811c9dc5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  String? get _profileNoticeMessage {
    if (_profileNoticeProvider == null) return null;

    final provider = _profileNoticeProvider!;
    return t(context, 'socialSignInSuccess').replaceAll('{provider}', provider);
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.96),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError
                  ? Theme.of(context).colorScheme.error
                  : const Color(0xFF00A79D),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF17324D),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continueWithPhone() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showMessage(t(context, 'phoneRequiredPeriod'), isError: true);
      return;
    }

    if (!_isValidIndonesianPhone(phone)) {
      _showMessage(t(context, 'invalidPhoneFormat'), isError: true);
      return;
    }

    final normalizedPhone = _normalizePhoneNumber(phone);
    final registeredNumbers = {
      '081234567890',
      '6281234567890',
      registeredPhoneNumber ?? '',
    }.where((value) => value.isNotEmpty).toSet();

    if (registeredNumbers.contains(
      normalizedPhone.replaceAll(RegExp(r'\D'), ''),
    )) {
      await CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: 'No. Telp Sudah Terdaftar', // t(context, 'phoneAlreadyRegistered')
        subtitle: 'Silahkan Menggunakan Nomor Telepon Lain',
        singleButtonText: 'Ubah No. Telp',
        onSinglePressed: () {
          Navigator.of(context).pop();
          // Optionally focus the field again
        },
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    setState(() => _isSubmitting = false);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phoneNumber: normalizedPhone,
          onVerified: () {
            if (!mounted) return;
            setState(() {
              _currentStep = SignUpStep.profile;
              _signupMethod = 'phone';
              _profileNoticeProvider = null;
            });
          },
        ),
      ),
    );
  }

  Future<void> _continueWithSocial(String provider) async {
    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _signupMethod = provider.toLowerCase();
      _currentStep = SignUpStep.profile;
      _profileNoticeProvider = provider;
      _nameController.text = provider == 'Google' ? 'Ayu Putri' : 'Alex Apple';
      _emailController.text = provider == 'Google'
          ? 'ayu@example.com'
          : 'alex@example.com';
    });
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (dialogContext, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: const Color(0xFF00A79D)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  void _continueToPin() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final birthDate = _birthDate;

    if (name.isEmpty) {
      _showMessage(t(context, 'fullNameRequired'), isError: true);
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage(t(context, 'invalidEmail'), isError: true);
      return;
    }

    if (birthDate == null) {
      _showMessage(t(context, 'birthDateRequired'), isError: true);
      return;
    }

    if (_selectedGender == null) {
      _showMessage(t(context, 'genderRequired'), isError: true);
      return;
    }

    setState(() => _currentStep = SignUpStep.pin);
  }

  Future<void> _savePin() async {
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (pin.isEmpty) {
      _showMessage(t(context, 'pinEmpty'), isError: true);
      return;
    }

    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      _showMessage(t(context, 'pinNumbersOnly'), isError: true);
      return;
    }

    if (pin.length != 6) {
      _showMessage(t(context, 'pinSixDigits'), isError: true);
      return;
    }

    if (confirmPin != pin) {
      _showMessage(t(context, 'pinMismatch'), isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = SupabaseAuthService();
      
      if (_signupMethod == 'phone') {
        await service.signUpWithPhone(
          phone: _phoneController.text.trim(),
          pin: pin,
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          birthDate: _birthDate ?? DateTime(2000),
          gender: _selectedGender ?? 'other',
        );
      } else {
        await service.completeSocialProfile(
          phone: _phoneController.text.trim(),
          pin: pin,
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          birthDate: _birthDate ?? DateTime(2000),
          gender: _selectedGender ?? 'other',
          provider: _signupMethod,
        );
      }

      registeredPinValue = _hashPin(pin);
      registeredPhoneNumber = _phoneController.text.trim().isEmpty
          ? null
          : _normalizePhoneNumber(_phoneController.text.trim());
      registeredUserName = _nameController.text.trim();
      registeredUserEmail = _emailController.text.trim();
      registeredUserGender = _selectedGender;
      registeredBirthDate = _birthDate;

      if (!mounted) return;
      setState(() => _currentStep = SignUpStep.success);
      
      await CustomBottomSheet.show(
        context,
        type: BottomSheetType.success,
        title: t(context, 'registrationSuccessful'),
        subtitle: t(context, 'registrationSuccessDesc'),
        singleButtonText: t(context, 'signIn'),
        isDismissible: false,
        onSinglePressed: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SignInScreen()),
            (route) => false,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(t(context, 'saveProfileFailed'), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  Theme.of(context).colorScheme.surface,
                  Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
          Positioned(
            top: -70,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF86D8C8).withValues(alpha: 0.24),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -30,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8AA8FF).withValues(alpha: 0.2),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 16 : 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: EdgeInsets.fromLTRB(
                                isCompact ? 18 : 24,
                                24,
                                isCompact ? 18 : 24,
                                24,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.72),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.72),
                                ),
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF7F9CCB,
                                    ).withValues(alpha: 0.16),
                                    blurRadius: 24,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Align(
                                    alignment: Alignment.centerRight,
                                    child: LanguageButton(),
                                  ),
                                  const SizedBox(height: 20),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 350),
                                    child: _buildStepContent(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case SignUpStep.phone:
        return _buildPhoneStep();
      case SignUpStep.profile:
        return _buildProfileStep();
      case SignUpStep.pin:
        return _buildPinStep();
      case SignUpStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, 'createAccount'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17324D),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t(context, 'createAccountSubtitle'),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _buildField(
          controller: _phoneController,
          hint: t(context, 'phoneExample'),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(13),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _continueWithPhone,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00A79D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    t(context, 'continue'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                t(context, 'or'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSocialButton(
                icon: const GoogleLogoIcon(size: 22),
                label: t(context, 'continueGoogle'),
                color: const Color(0xFF4285F4),
                onPressed: () => _continueWithSocial('Google'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSocialButton(
                icon: Icon(
                  Icons.apple,
                  color: const Color(0xFF17324D),
                  size: 22,
                ),
                label: t(context, 'continueApple'),
                color: const Color(0xFF17324D),
                onPressed: () => _continueWithSocial('Apple'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t(context, 'alreadyHaveAccount'),
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SignInScreen()),
              ),
              child: Text(
                t(context, 'signIn'),
                style: const TextStyle(
                  color: Color(0xFF00A79D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, 'completeProfile'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17324D),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _signupMethod == 'phone'
              ? t(context, 'completeProfilePhone')
              : t(context, 'completeProfileSocial'),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        if (_profileNoticeMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF00A79D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00A79D).withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF00A79D),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _profileNoticeMessage!,
                    style: const TextStyle(
                      color: Color(0xFF17324D),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _buildField(controller: _nameController, hint: t(context, 'fullName')),
        const SizedBox(height: 12),
        _buildField(
          controller: _emailController,
          hint: t(context, 'email'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickBirthDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE7F5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cake_rounded,
                  color: Color(0xFF00A79D),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _birthDate == null
                      ? t(context, 'birthDate')
                      : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                  style: TextStyle(
                    color: _birthDate == null
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF17324D),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children:
              [
                t(context, 'male'),
                t(context, 'female'),
                t(context, 'other'),
              ].map((gender) {
                final selected = _selectedGender == gender;
                return ChoiceChip(
                  label: Text(gender),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedGender = gender),
                  selectedColor: const Color(
                    0xFF00A79D,
                  ).withValues(alpha: 0.14),
                  labelStyle: TextStyle(
                    color: selected
                        ? const Color(0xFF00A79D)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _continueToPin,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00A79D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              t(context, 'continue'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, 'createPin'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17324D),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t(context, 'createPinDesc'),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _buildSecureField(
          controller: _pinController,
          hint: t(context, 'pin'),
          isVisible: _showPin,
          toggle: () => setState(() => _showPin = !_showPin),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
        const SizedBox(height: 12),
        _buildSecureField(
          controller: _confirmPinController,
          hint: t(context, 'confirmPin'),
          isVisible: _showConfirmPin,
          toggle: () => setState(() => _showConfirmPin = !_showConfirmPin),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _savePin,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00A79D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              t(context, 'savePin'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00A79D).withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF00A79D),
            size: 54,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          t(context, 'registrationSuccessful'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17324D),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t(context, 'registrationSuccessDesc'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const SignInScreen()),
              (route) => false,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00A79D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              t(context, 'goToSignIn'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required Widget icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF17324D),
          side: const BorderSide(color: Color(0xFFDCE7F5)),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.55),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE7F5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8CA6C8).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          prefixText: hint == 'Example: 81234567890' ? '+62 ' : null,
          prefixStyle: const TextStyle(
            color: Color(0xFF17324D),
            fontWeight: FontWeight.w600,
          ),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSecureField({
    required TextEditingController controller,
    required String hint,
    required bool isVisible,
    required VoidCallback toggle,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE7F5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8CA6C8).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: !isVisible,
              inputFormatters: inputFormatters,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          IconButton(
            onPressed: toggle,
            icon: Icon(
              isVisible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: const Color(0xFF00A79D),
            ),
          ),
        ],
      ),
    );
  }
}
