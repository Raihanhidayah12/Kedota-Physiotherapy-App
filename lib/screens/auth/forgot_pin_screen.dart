import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header teal — sama persis dengan sign_in_screen
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Image.asset(
                  'assets/image/logo 2.png',
                  height: 56,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                const Text(
                  'K E D O T A',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF00A79D),
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'P H Y S I O T H E R A P Y',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00A79D).withValues(alpha: 0.85),
                    letterSpacing: 4.5,
                  ),
                ),
              ],
            ),
          ),
          // White card bawah
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button + judul "Lupa PIN"
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF1E293B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          t(context, 'forgotPin'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const StepIndicator(activeStep: 1),
                    const SizedBox(height: 22),
                    // Judul + deskripsi
                    Text(
                      t(context, 'enterPhoneNumberTitle'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t(context, 'forgotPinDesc'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Label
                    Text(
                      t(context, 'phoneNumber'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Input nomor telepon — sama dengan sign_in_screen
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          _buildIndonesianFlag(),
                          const SizedBox(width: 8),
                          const Text(
                            '+62',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 1,
                            height: 20,
                            color: const Color(0xFFE2E8F0),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(13),
                              ],
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: t(context, 'phoneExample'),
                                hintStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Tombol Kirim OTP
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _resetPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A79D),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                                  color: Colors.white,
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
    );

    return Scaffold(
      backgroundColor: const Color(0xFFE8F6F4),
      body: AnimatedBuilder(
        animation: _entranceController,
        builder: (context, child) => FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(scale: _scaleAnimation, child: child),
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _buildIndonesianFlag() {
    return Container(
      width: 20,
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
      ),
      child: const Column(
        children: [
          Expanded(child: ColoredBox(color: Color(0xFFE53E3E))),
          Expanded(child: ColoredBox(color: Colors.white)),
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
    final dateText = _selectedBirthDate != null
        ? '${_selectedBirthDate!.day.toString().padLeft(2, '0')}/${_selectedBirthDate!.month.toString().padLeft(2, '0')}/${_selectedBirthDate!.year}'
        : t(context, 'selectBirthDateHint');

    return Scaffold(
      backgroundColor: const Color(0xFFE8F6F4),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header teal
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Image.asset(
                    'assets/image/logo 2.png',
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'K E D O T A',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00A79D),
                      letterSpacing: 4.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'P H Y S I O T H E R A P Y',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00A79D).withValues(alpha: 0.85),
                      letterSpacing: 4.5,
                    ),
                  ),
                ],
              ),
            ),
            // White card bawah
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back + judul
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Color(0xFF1E293B),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            t(context, 'forgotPin'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const StepIndicator(activeStep: 3),
                      const SizedBox(height: 22),
                      Text(
                        t(context, 'verifyBirthDateTitle'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t(context, 'verifyBirthDateDesc'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        t(context, 'birthDate'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateText,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _selectedBirthDate != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: _selectedBirthDate != null
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF94A3B8),
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
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (_isLoading || _cooldownSeconds > 0)
                              ? null
                              : _verifyBirthDate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A79D),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
                                    color: Colors.white,
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
      )
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
    if (value.isEmpty) {
      return const SizedBox(width: 68, height: 68);
    }

    final isBackspace = value == 'back';

    if (isBackspace) {
      return GestureDetector(
        onTap: _onBackspace,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00A79D), width: 2),
          ),
          child: const Center(
            child: Icon(
              Icons.backspace_outlined,
              color: Color(0xFF00A79D),
              size: 24,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onNumpadTap(value),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _firstPin;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 36),

            // Back + judul atas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_isConfirming) {
                        setState(() {
                          _isConfirming = false;
                          _confirmPin = '';
                        });
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF1E293B),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    t(context, 'forgotPin'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Icon gembok — sama dengan phone_create_pin_screen
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  size: 36,
                  color: Color(0xFF00A79D),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Step indicator
            const StepIndicator(activeStep: 4),
            const SizedBox(height: 16),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _isConfirming
                    ? t(context, 'confirmPinDesc')
                    : t(context, 'createNewPinDesc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF334155),
                  height: 1.45,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Error teks
            if (_isPinError)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _isSameAsOldPin
                      ? t(context, 'sameAsOldPinError')
                      : t(context, 'confirmPinMismatchError'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),

            // 6 PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < currentPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPinError
                        ? (isFilled
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFE2E8F0))
                        : (isFilled
                              ? const Color(0xFF00A79D)
                              : const Color(0xFFE2E8F0)),
                  ),
                );
              }),
            ),

            const Spacer(),

            // Numpad — sama persis dengan phone_create_pin_screen
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildNumpadButton('1')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('2')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('3')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildNumpadButton('4')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('5')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('6')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildNumpadButton('7')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('8')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('9')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildNumpadButton('')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('0')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('back')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),
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
