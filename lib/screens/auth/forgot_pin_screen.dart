import 'dart:async';
import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../utils/phone_validator.dart';
import '../../widgets/custom_bottom_sheet.dart';
import 'otp_verification_screen.dart';
import 'sign_in_screen.dart';

class StepIndicator extends StatelessWidget {
  final int activeStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.activeStep,
    this.totalSteps = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index == activeStep - 1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 12,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00A79D) : const Color(0xFFD8E4EB),
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }
}

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
  bool _isLoading = false;

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

  void _showNotificationSheet(String message, {bool isError = false}) {
    CustomBottomSheet.show(
      context,
      type: isError ? BottomSheetType.error : BottomSheetType.success,
      title: isError ? 'Informasi' : 'Berhasil',
      subtitle: message,
      singleButtonText: t(context, 'close'),
      onSinglePressed: () => Navigator.of(context).pop(),
    );
  }

  Future<void> _resetPin() async {
    if (_isLoading) return;
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showNotificationSheet(t(context, 'enterPhoneError'), isError: true);
      return;
    }

    if (!PhoneValidator.isValidIndonesianPhone(phone)) {
      _showNotificationSheet(t(context, 'validPhoneError'), isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final accountResult = await SupabaseAuthService().checkAccountStatus(
        phone,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!accountResult.isRegistered) {
        _showNotificationSheet(
          t(context, 'numberNotRegistered'),
          isError: true,
        );
        return;
      }

      final normalizedPhone = PhoneValidator.normalizePhoneNumber(phone);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phoneNumber: normalizedPhone,
            isDormant: accountResult.isDormant,
            targetEmail: accountResult.email,
            onVerified: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      BirthDateVerificationScreen(phoneNumber: normalizedPhone),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showNotificationSheet(t(context, 'resetPinFailed'), isError: true);
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
                          child: Container(
                            padding: EdgeInsets.fromLTRB(
                              isCompact ? 18 : 24,
                              24,
                              isCompact ? 18 : 24,
                              24,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF7F9CCB,
                                  ).withValues(alpha: 0.12),
                                  blurRadius: 22,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                      ),
                                      color: const Color(0xFF17324D),
                                      tooltip: t(context, 'back'),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.72),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          side: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          t(context, 'forgotPin'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF17324D),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 48),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const StepIndicator(activeStep: 1),
                                const SizedBox(height: 22),
                                Text(
                                  t(context, 'enterPhoneNumberTitle'),
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
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
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
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
                                    onPressed: _isLoading ? null : _resetPin,
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
                                              color: Colors.white,
                                              strokeWidth: 2.4,
                                            ),
                                          )
                                        : Text(
                                            t(context, 'sendOtp'),
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

  void _showNotificationSheet(String message, {bool isError = false}) {
    CustomBottomSheet.show(
      context,
      type: isError ? BottomSheetType.error : BottomSheetType.success,
      title: isError ? 'Informasi' : 'Berhasil',
      subtitle: message,
      singleButtonText: t(context, 'close'),
      onSinglePressed: () => Navigator.of(context).pop(),
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
      _showNotificationSheet(t(context, 'selectBirthDateError'), isError: true);
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
            builder: (_) => ResetPinFormScreen(phoneNumber: widget.phoneNumber),
          ),
        );
      } else {
        _showNotificationSheet(
          t(context, 'birthDateMismatchError'),
          isError: true,
        );
        _startCooldownTimer();
      }
    } catch (e) {
      if (!mounted) return;
      _showNotificationSheet(t(context, 'resetPinFailed'), isError: true);
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
    final compactTitleSpacing = screenWidth < 360 ? 12.0 : 16.0;

    final dateText = _selectedBirthDate != null
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
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 18 : 24,
                        24,
                        isCompact ? 18 : 24,
                        24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF7F9CCB,
                            ).withValues(alpha: 0.12),
                            blurRadius: 22,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: const Color(0xFF17324D),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.72,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              SizedBox(width: compactTitleSpacing),
                              Expanded(
                                child: Text(
                                  t(context, 'verifyBirthDateTitle'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF17324D),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              SizedBox(width: compactTitleSpacing + 22),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const StepIndicator(activeStep: 3),
                          const SizedBox(height: 22),
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
  bool _isPinError = false;
  bool _isSameAsOldPin = false;

  void _showPinError() {
    setState(() {
      _isPinError = true;
      _isSameAsOldPin = false;
      _confirmPin = '';
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _isPinError = false);
    });
  }

  void _showNotificationSheet(String message, {bool isError = false}) {
    CustomBottomSheet.show(
      context,
      type: isError ? BottomSheetType.error : BottomSheetType.success,
      title: isError ? 'Informasi' : 'Berhasil',
      subtitle: message,
      singleButtonText: t(context, 'close'),
      onSinglePressed: () => Navigator.of(context).pop(),
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
      _showPinError();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await SupabaseAuthService().updateUserPin(
        phone: widget.phoneNumber,
        newPin: _firstPin,
        allowSamePin: true,
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PinResetSuccessScreen()),
          (route) => false,
        );
      } else {
        _showNotificationSheet(t(context, 'resetPinFailed'), isError: true);
        setState(() {
          _firstPin = '';
          _confirmPin = '';
          _isConfirming = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg == 'sameAsOldPin') {
        // Tampilkan error inline — dots merah + teks
        setState(() {
          _isPinError = true;
          _isSameAsOldPin = true;
          _firstPin = '';
          _confirmPin = '';
          _isConfirming = false;
        });
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _isPinError = false);
        });
      } else {
        _showNotificationSheet(t(context, 'resetPinFailed'), isError: true);
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
    final isVeryCompact = screenWidth < 340;
    final dotSize = isVeryCompact ? 12.0 : 16.0;
    final dotGap = isVeryCompact ? 6.0 : 8.0;
    final numpadGap = isVeryCompact ? 10.0 : 16.0;
    final titleSpacing = isVeryCompact ? 12.0 : 16.0;

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
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 18 : 24,
                        24,
                        isCompact ? 18 : 24,
                        24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF7F9CCB,
                            ).withValues(alpha: 0.12),
                            blurRadius: 22,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
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
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.72,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              SizedBox(width: titleSpacing),
                              Expanded(
                                child: Text(
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
                              ),
                              SizedBox(width: titleSpacing + 22),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const StepIndicator(activeStep: 4),
                          const SizedBox(height: 18),
                          Text(
                            _isConfirming
                                ? t(context, 'confirmPinDesc')
                                : t(context, 'createNewPinDesc'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF6B8092),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              final isFilled = index < currentPin.length;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: EdgeInsets.symmetric(
                                  horizontal: dotGap,
                                ),
                                width: dotSize,
                                height: dotSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isFilled
                                      ? (_isPinError
                                            ? Colors.red.shade400
                                            : const Color(0xFF00A79D))
                                      : Colors.white.withValues(alpha: 0.8),
                                  border: Border.all(
                                    color: isFilled
                                        ? (_isPinError
                                              ? Colors.red.shade400
                                              : const Color(0xFF00A79D))
                                        : const Color(0xFFC0D0E0),
                                    width: 2,
                                  ),
                                ),
                              );
                            }),
                          ),
                          AnimatedOpacity(
                            opacity: _isPinError ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                _isSameAsOldPin
                                    ? t(context, 'sameAsOldPinError')
                                    : t(context, 'confirmPinMismatchError'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: isVeryCompact ? 1.28 : 1.35,
                                  crossAxisSpacing: numpadGap,
                                  mainAxisSpacing: 14,
                                ),
                            itemCount: 12,
                            itemBuilder: (context, index) {
                              if (index == 9) {
                                return _buildNumpadButton('');
                              }
                              if (index == 10) {
                                return _buildNumpadButton('0');
                              }
                              if (index == 11) {
                                return _buildNumpadButton('back');
                              }
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
        ],
      ),
    );
  }
}

class PinResetSuccessScreen extends StatefulWidget {
  const PinResetSuccessScreen({super.key});

  @override
  State<PinResetSuccessScreen> createState() => _PinResetSuccessScreenState();
}

class _PinResetSuccessScreenState extends State<PinResetSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final AnimationController _fadeController;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;
  late final Animation<double> _fadeIn;

  int _countdown = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _checkOpacity = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeIn,
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _checkController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fadeController.forward();
    });

    // Countdown 3 detik lalu ke SignInScreen
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        _goToSignIn();
      }
    });
  }

  void _goToSignIn() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _checkController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF7F4), Color(0xFFF8FBFF), Color(0xFFF5EFFF)],
          ),
        ),
        child: Stack(
          children: [
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
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 20 : 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _checkScale,
                        child: FadeTransition(
                          opacity: _checkOpacity,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(
                                0xFF00A79D,
                              ).withValues(alpha: 0.12),
                              border: Border.all(
                                color: const Color(
                                  0xFF00A79D,
                                ).withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF00A79D),
                              size: 72,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FadeTransition(
                        opacity: _fadeIn,
                        child: Column(
                          children: [
                            Text(
                              t(context, 'pinUpdatedSuccessTitle'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isCompact ? 22 : 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF00A79D),
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: isCompact ? 10 : 12),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: isCompact ? 13 : 14,
                                  color: const Color(0xFF64748B),
                                  height: 1.6,
                                ),
                                children: [
                                  const TextSpan(
                                    text:
                                        'Anda akan diarahkan ke halaman login dalam ',
                                  ),
                                  TextSpan(
                                    text: '$_countdown detik',
                                    style: const TextStyle(
                                      color: Color(0xFF00A79D),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: '\nuntuk mencoba PIN Anda!',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Progress indicator countdown
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: _countdown / 3,
                                    strokeWidth: 3.5,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    color: const Color(0xFF00A79D),
                                  ),
                                  Text(
                                    '$_countdown',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF00A79D),
                                    ),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }
}
