import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/language_button.dart';
import '../../widgets/custom_bottom_sheet.dart';
import 'otp_verification_screen.dart';
import 'sign_in_screen.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  bool _isValidIndonesianPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;

    // Format: 628xxxxxxxxx (11-13 digits after 62)
    if (digits.startsWith('628')) {
      return digits.length >= 12 && digits.length <= 14;
    }

    // Format: 08xxxxxxxxx (10-12 digits)
    if (digits.startsWith('08')) {
      return digits.length >= 11 && digits.length <= 13;
    }

    // Format: 8xxxxxxxxx (9-11 digits without 0 or country code)
    if (digits.startsWith('8')) {
      return digits.length >= 10 && digits.length <= 12;
    }

    return false;
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
    _phoneController.dispose();
    super.dispose();
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        elevation: 10,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00A79D).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: const Color(0xFF00A79D),
                size: 18,
              ),
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

  Future<void> _resetPin() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showModernSnackBar(t(context, 'enterPhoneError'), isError: true);
      return;
    }

    if (!_isValidIndonesianPhone(phone)) {
      _showModernSnackBar(t(context, 'validPhoneError'), isError: true);
      return;
    }

    try {
      final accountResult = await SupabaseAuthService().checkAccountStatus(phone);

      if (!mounted) return;

      if (!accountResult.isRegistered) {
        _showModernSnackBar(t(context, 'numberNotRegistered'), isError: true);
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phoneNumber: _normalizePhoneNumber(phone),
            isDormant: accountResult.isDormant,
            targetEmail: accountResult.email,
            onVerified: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => BirthDateVerificationScreen(
                    phoneNumber: _normalizePhoneNumber(phone),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showModernSnackBar(t(context, 'resetPinFailed'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEAF7F4),
                  Color(0xFFF8FBFF),
                  Color(0xFFF5EFFF),
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
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
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
                                color: Colors.white.withValues(alpha: 0.62),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7F9CCB).withValues(alpha: 0.16),
                                    blurRadius: 24,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        icon: const Icon(Icons.arrow_back_rounded),
                                        color: const Color(0xFF17324D),
                                        tooltip: t(context, 'back'),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.white.withValues(alpha: 0.72),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                            side: BorderSide(
                                              color: Colors.white.withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox.shrink(), // Language button hidden - will be in settings
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    t(context, 'forgotPin'),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF17324D),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t(context, 'forgotPinDesc'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B8092),
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Text(
                                    t(context, 'phoneNumber'),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF17324D),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF17324D),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: t(context, 'phoneExample'),
                                      hintStyle: const TextStyle(
                                        color: Color(0xFFA0B0C0),
                                        fontSize: 14,
                                      ),
                                      prefixIcon: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            right: BorderSide(
                                              color: Color(0xFFE2E8F0),
                                            ),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '🇮🇩',
                                              style: TextStyle(fontSize: 18),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              '+62',
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF17324D),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.72),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF00A79D),
                                          width: 1.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: FilledButton(
                                      onPressed: _resetPin,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF00A79D),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        t(context, 'resendOtp'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF00A79D), width: 1.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Text(
                                        t(context, 'back'),
                                        style: const TextStyle(
                                          color: Color(0xFF00A79D),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
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
}

class BirthDateVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const BirthDateVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<BirthDateVerificationScreen> createState() =>
      _BirthDateVerificationScreenState();
}

class _BirthDateVerificationScreenState
    extends State<BirthDateVerificationScreen> {
  DateTime? _selectedBirthDate;
  bool _isLoading = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  void _showModernSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        elevation: 10,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00A79D).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: const Color(0xFF00A79D),
                size: 18,
              ),
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

  void _startCooldownTimer() {
    setState(() => _cooldownSeconds = 3);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldownSeconds > 1) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (_cooldownSeconds > 0) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00A79D),
              onPrimary: Colors.white,
              onSurface: Color(0xFF17324D),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  Future<void> _verifyBirthDate() async {
    if (_selectedBirthDate == null) {
      _showModernSnackBar(t(context, 'selectBirthDateError'), isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isValid = await SupabaseAuthService().verifyBirthDate(
        phone: widget.phoneNumber,
        birthDate: _selectedBirthDate!,
      );

      if (!mounted) return;

      if (isValid) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResetPinFormScreen(
              phoneNumber: widget.phoneNumber,
            ),
          ),
        );
      } else {
        _showModernSnackBar(
          t(context, 'birthDateMismatchError'),
          isError: true,
        );
        _startCooldownTimer();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;

    String dateText = _selectedBirthDate != null
        ? '${_selectedBirthDate!.day.toString().padLeft(2, '0')}/${_selectedBirthDate!.month.toString().padLeft(2, '0')}/${_selectedBirthDate!.year}'
        : t(context, 'selectBirthDateHint');

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEAF7F4),
                  Color(0xFFF8FBFF),
                  Color(0xFFF5EFFF),
                ],
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
                          color: Colors.white.withValues(alpha: 0.62),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7F9CCB).withValues(alpha: 0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  color: const Color(0xFF17324D),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(alpha: 0.72),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                const SizedBox.shrink(), // Language button hidden - will be in settings
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              t(context, 'verifyBirthDateTitle'),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF17324D),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t(context, 'verifyBirthDateDesc'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B8092),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              t(context, 'birthDate'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF17324D),
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dateText,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: _selectedBirthDate != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: _selectedBirthDate != null
                                            ? const Color(0xFF17324D)
                                            : const Color(0xFFA0B0C0),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      color: Color(0xFF00A79D),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: (_isLoading || _cooldownSeconds > 0)
                                    ? null
                                    : _verifyBirthDate,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF00A79D),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _cooldownSeconds > 0
                                            ? 'Tunggu $_cooldownSeconds detik...'
                                            : t(context, 'next'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
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
        ],
      ),
    );
  }
}

class ResetPinFormScreen extends StatefulWidget {
  final String phoneNumber;

  const ResetPinFormScreen({super.key, required this.phoneNumber});

  @override
  State<ResetPinFormScreen> createState() => _ResetPinFormScreenState();
}

class _ResetPinFormScreenState extends State<ResetPinFormScreen> {
  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;

  void _showModernSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        elevation: 10,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00A79D).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: const Color(0xFF00A79D),
                size: 18,
              ),
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

  void _onNumpadTap(String val) {
    if (_isLoading) return;

    if (!_isConfirming) {
      if (_firstPin.length < 6) {
        setState(() => _firstPin += val);
        if (_firstPin.length == 6) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() => _isConfirming = true);
            }
          });
        }
      }
    } else {
      if (_confirmPin.length < 6) {
        setState(() => _confirmPin += val);
        if (_confirmPin.length == 6) {
          _handlePinSubmission();
        }
      }
    }
  }

  void _onBackspace() {
    if (_isLoading) return;

    if (!_isConfirming) {
      if (_firstPin.isNotEmpty) {
        setState(() {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        });
      }
    } else {
      if (_confirmPin.isNotEmpty) {
        setState(() {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        });
      } else {
        setState(() {
          _isConfirming = false;
          _firstPin = '';
        });
      }
    }
  }

  Future<void> _handlePinSubmission() async {
    if (_firstPin != _confirmPin) {
      _showModernSnackBar(t(context, 'confirmPinMismatchError'), isError: true);
      setState(() {
        _firstPin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await SupabaseAuthService().updateUserPin(
        phone: widget.phoneNumber,
        newPin: _firstPin,
      );

      if (!mounted) return;

      if (success) {
        CustomBottomSheet.show(
          context,
          type: BottomSheetType.success,
          title: t(context, 'pinUpdatedSuccessTitle'),
          subtitle: t(context, 'pinUpdatedSuccessDesc'),
          singleButtonText: t(context, 'signIn'),
          isDismissible: false,
          onSinglePressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const SignInScreen()),
              (route) => false,
            );
          },
        );
      } else {
        _showModernSnackBar(t(context, 'resetPinFailed'), isError: true);
        setState(() {
          _firstPin = '';
          _confirmPin = '';
          _isConfirming = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildNumpadButton(String value) {
    final isBlank = value.isEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBlank
            ? null
            : () {
                if (value == 'back') {
                  _onBackspace();
                } else {
                  _onNumpadTap(value);
                }
              },
        borderRadius: BorderRadius.circular(100),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBlank
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.65),
            border: isBlank
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: Center(
            child: value == 'back'
                ? const Icon(
                    Icons.backspace_outlined,
                    color: Color(0xFF17324D),
                    size: 22,
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF17324D),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _firstPin;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEAF7F4),
                  Color(0xFFF8FBFF),
                  Color(0xFFF5EFFF),
                ],
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
                          color: Colors.white.withValues(alpha: 0.62),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7F9CCB).withValues(alpha: 0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (_isConfirming) {
                                      setState(() {
                                        _isConfirming = false;
                                        _confirmPin = '';
                                      });
                                    } else {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  color: const Color(0xFF17324D),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(alpha: 0.72),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                const SizedBox.shrink(), // Language button hidden - will be in settings
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isConfirming
                                  ? t(context, 'confirmNewPin')
                                  : t(context, 'createNewPin'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF17324D),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t(context, 'createNewPinDesc'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF6B8092),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(6, (index) {
                                final isFilled = index < currentPin.length;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isFilled
                                        ? const Color(0xFF00A79D)
                                        : Colors.white.withValues(alpha: 0.8),
                                    border: Border.all(
                                      color: isFilled
                                          ? const Color(0xFF00A79D)
                                          : const Color(0xFFC0D0E0),
                                      width: 2,
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 32),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 1.35,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: 12,
                              itemBuilder: (context, index) {
                                if (index == 9) return _buildNumpadButton('');
                                if (index == 10) return _buildNumpadButton('0');
                                if (index == 11) return _buildNumpadButton('back');
                                return _buildNumpadButton('${index + 1}');
                              },
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
        ],
      ),
    );
  }
}
