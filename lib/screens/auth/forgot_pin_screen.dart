import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../utils/phone_validator.dart';
import '../../widgets/custom_bottom_sheet.dart';
import '../../widgets/custom_date_picker.dart';
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

class ForgotPinAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int activeStep;
  final VoidCallback? onBackPressed;

  const ForgotPinAppBar({
    super.key,
    required this.activeStep,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B), size: 22),
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Lupa PIN',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isActive = index < activeStep;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF00A79D) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 16);
}

// ─── Shared logo header ───────────────────────────────────────────────────────
Widget _buildLogoHeader(BuildContext context) {
  final h = MediaQuery.of(context).size.height;
  final w = MediaQuery.of(context).size.width;
  final logoH = (h * 0.075).clamp(44.0, 64.0);
  final titleSize = (w * 0.046).clamp(14.0, 20.0);
  final subtitleSize = (w * 0.025).clamp(8.0, 11.0);
  final vPad = h < 640 ? 14.0 : 22.0;
  return Padding(
    padding: EdgeInsets.symmetric(vertical: vPad),
    child: Column(
      children: [
        Image.asset(
          'assets/image/logo 2.png',
          height: logoH,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 8),
        Text(
          'K E D O T A',
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF00A79D),
            letterSpacing: 4.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'P H Y S I O T H E R A P Y',
          style: TextStyle(
            fontSize: subtitleSize,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF00A79D).withValues(alpha: 0.85),
            letterSpacing: 3.5,
          ),
        ),
      ],
    ),
  );
}

// ─── ForgotPin-specific OTP screen ─────────────────────────────────────────
class ForgotPinOtpScreen extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback onVerified;

  const ForgotPinOtpScreen({
    super.key,
    required this.phoneNumber,
    required this.onVerified,
  });

  @override
  State<ForgotPinOtpScreen> createState() => _ForgotPinOtpScreenState();
}

class _ForgotPinOtpScreenState extends State<ForgotPinOtpScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _timer;
  int _secondsRemaining = 59;
  bool _isError = false;

  static const _validDummyOtps = {'1234', '5555', '0000', '9999'};

  @override
  void initState() {
    super.initState();
    _startTimer();
    _otpController.addListener(_checkOtpComplete);
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.removeListener(_checkOtpComplete);
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = 59;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining -= 1;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String _formatPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final prefix = digits.substring(0, 4);
      final suffix = digits.substring(digits.length - 4);
      return '$prefix-****-$suffix';
    }
    return phone;
  }

  void _checkOtpComplete() {
    if (_otpController.text.isNotEmpty) {
      HapticFeedback.selectionClick();
    }
    if (_otpController.text.length == 4) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _verifyOtp();
      });
    } else {
      if (_isError) setState(() => _isError = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (_validDummyOtps.contains(otp)) {
      widget.onVerified();
      return;
    }

    setState(() {
      _isError = true;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final formattedPhone = _formatPhoneNumber(widget.phoneNumber);
    final seconds = _secondsRemaining.toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar dengan back arrow + "Lupa PIN" + 4 progress bar — sesuai Figma
      appBar: ForgotPinAppBar(
        activeStep: 1,
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              const Text(
                'Verifikasi OTP',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle — 4 digit
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                  children: [
                    TextSpan(text: t(context, 'enterOtpSentTo')),
                    TextSpan(
                      text: formattedPhone,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Error text inline
              if (_isError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    t(context, 'otpInvalid'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),

              // 4-box OTP input — responsive dengan LayoutBuilder
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => _focusNode.requestFocus(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Tidak ada minimum clamp agar tidak overflow di layar sempit
                      final boxSize = ((constraints.maxWidth - 36) / 4)
                          .clamp(0.0, 72.0);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final isActive = index == _otpController.text.length;
                          final char = _otpController.text.length > index
                              ? _otpController.text[index]
                              : '';

                          return Container(
                            margin:
                                EdgeInsets.only(right: index == 3 ? 0 : 12),
                            width: boxSize,
                            height: boxSize * 1.07,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isError
                                    ? const Color(0xFFEF4444)
                                    : (isActive && _focusNode.hasFocus
                                          ? const Color(0xFF00A79D)
                                          : const Color(0xFFE2E8F0)),
                                width:
                                    _isError || (isActive && _focusNode.hasFocus)
                                        ? 1.5
                                        : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (char.isNotEmpty)
                                  Text(
                                    char,
                                    style: TextStyle(
                                      fontSize: boxSize * 0.4,
                                      fontWeight: FontWeight.w800,
                                      color: _isError
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF1E293B),
                                    ),
                                  )
                                else if (isActive && _focusNode.hasFocus)
                                  const _ForgotPinBlinkingCursor(),
                                Positioned(
                                  bottom: 10,
                                  child: Container(
                                    width: boxSize * 0.33,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: _isError
                                          ? const Color(0xFFEF4444)
                                          : (char.isNotEmpty ||
                                                    (isActive &&
                                                        _focusNode.hasFocus)
                                                ? const Color(0xFF00A79D)
                                                : const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),

              // Hidden text field
              SizedBox(
                width: 1,
                height: 1,
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _otpController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    autofocus: true,
                    decoration: const InputDecoration(border: InputBorder.none),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Resend timer / button
              if (_secondsRemaining > 0)
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${t(context, 'resendIn')} ',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: '00:$seconds',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF00A79D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                TextButton(
                  onPressed: _startTimer,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00A79D),
                  ),
                  child: Text(
                    t(context, 'resendOtp'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00A79D),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress bar — sudah dipindahkan ke dalam _ForgotPinOtpScreenState

// Blinking cursor for ForgotPinOtpScreen
class _ForgotPinBlinkingCursor extends StatefulWidget {
  const _ForgotPinBlinkingCursor();

  @override
  State<_ForgotPinBlinkingCursor> createState() => _ForgotPinBlinkingCursorState();
}

class _ForgotPinBlinkingCursorState extends State<_ForgotPinBlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFF00A79D),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  void _showNotificationSheet(String message, {bool isError = false}) {
    CustomBottomSheet.show(
      context,
      type: isError ? BottomSheetType.error : BottomSheetType.success,
      title: isError ? 'Informasi' : 'Berhasil',
      subtitle: message,
      singleButtonText: t(context, 'closeBtn'),
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
          builder: (_) => ForgotPinOtpScreen(
            phoneNumber: normalizedPhone,
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
          // Header teal
          _buildLogoHeader(context).animate().fade(duration: 500.ms).slideY(begin: 0.2, curve: Curves.easeOutQuad),
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
                    GestureDetector(
                      onTap: () => _phoneFocusNode.requestFocus(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _phoneFocusNode.hasFocus
                                ? const Color(0xFF00A79D)
                                : const Color(0xFFE2E8F0),
                            width: _phoneFocusNode.hasFocus ? 1.5 : 1.0,
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
                                focusNode: _phoneFocusNode,
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
                    ),
                    const SizedBox(height: 20),
                    // Tombol Kirim OTP
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF007F78), Color(0xFF00A79D)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _resetPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
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
                    ),
                    ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                  ),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      body: content,
    );
  }

  Widget _buildIndonesianFlag() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        width: 20,
        height: 14,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFFCE1126),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.white,
              ),
            ),
          ],
        ),
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
  final _dobController = TextEditingController();
  DateTime? _selectedBirthDate;
  bool _isLoading = false;
  bool _isDobError = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _dobController.addListener(() {
      if (_isDobError && _dobController.text.isNotEmpty) {
        setState(() => _isDobError = false);
      }
      _parseTypedDate(_dobController.text);
    });
  }

  void _parseTypedDate(String input) {
    final parts = input.split('/');
    if (parts.length == 3 &&
        parts[0].length == 2 &&
        parts[1].length == 2 &&
        parts[2].length == 4) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        try {
          final dt = DateTime(year, month, day);
          if (dt.year == year && dt.month == month && dt.day == day) {
            _selectedBirthDate = dt;
          }
        } catch (_) {}
      }
    }
  }

  void _showNotificationSheet(String message, {bool isError = false}) {
    CustomBottomSheet.show(
      context,
      type: isError ? BottomSheetType.error : BottomSheetType.success,
      title: isError ? 'Informasi' : 'Berhasil',
      subtitle: message,
      singleButtonText: t(context, 'closeBtn'),
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
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (_cooldownSeconds > 0) return;
    final now = DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => CustomDatePickerDialog(
        initialDate: _selectedBirthDate ?? DateTime(2000, 1, 1),
        firstDate: DateTime(1920),
        lastDate: now,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _dobController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        _isDobError = false;
      });
    }
  }

  Future<void> _verifyBirthDate() async {
    if (_selectedBirthDate == null) {
      setState(() => _isDobError = true);
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
        setState(() => _isDobError = true);
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const ForgotPinAppBar(activeStep: 2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verifikasi Tanggal Lahir',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              Text(
                t(context, 'verifyBirthDateDesc'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
              ),
              const SizedBox(height: 28),
              const Text(
                'Tanggal Lahir',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isDobError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                    width: _isDobError ? 1.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.only(left: 14, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dobController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                        decoration: const InputDecoration(
                          hintText: 'dd/mm/yyyy',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF00A79D), size: 20),
                    ),
                  ],
                ),
              ),
              if (_isDobError) ...[
                const SizedBox(height: 6),
                Text(
                  t(context, 'selectBirthDateError'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: (_isLoading || _cooldownSeconds > 0)
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF007F78), Color(0xFF00A79D)],
                          ),
                    color: (_isLoading || _cooldownSeconds > 0)
                        ? const Color(0xFF94A3B8)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    onPressed: (_isLoading || _cooldownSeconds > 0) ? null : _verifyBirthDate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(
                            _cooldownSeconds > 0
                                ? t(context, 'wait30Seconds').replaceAll('{seconds}', '$_cooldownSeconds')
                                : 'Konfirmasi',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      singleButtonText: t(context, 'closeBtn'),
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
      // Placeholder transparan — ukuran mengikuti AspectRatio
      return AspectRatio(aspectRatio: 1, child: const SizedBox.shrink());
    }

    final isBackspace = value == 'back';

    if (isBackspace) {
      return GestureDetector(
        onTap: _onBackspace,
        child: LayoutBuilder(
          builder: (context, c) => Container(
            height: c.maxWidth * 0.76,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00A79D), width: 2),
            ),
            child: Center(
              child: Icon(
                Icons.backspace_outlined,
                color: const Color(0xFF00A79D),
                size: c.maxWidth * 0.35,
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onNumpadTap(value),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
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
            child: LayoutBuilder(
              builder: (context, c) => Text(
                value,
                style: TextStyle(
                  fontSize: c.maxWidth * 0.35,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ForgotPinAppBar(
        activeStep: _isConfirming ? 4 : 3,
        onBackPressed: () {
          if (_isConfirming) {
            setState(() {
              _isConfirming = false;
              _confirmPin = '';
            });
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              
              // Title
              Text(
                _isConfirming ? t(context, 'confirmPin') : t(context, 'createNewPin'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _isConfirming
                      ? t(context, 'confirmPinDesc')
                      : t(context, 'createNewPinDesc'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ),

              const SizedBox(height: 32),

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
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 18,
                    height: 18,
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

              const SizedBox(height: 48),

              // Numpad
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Padding(
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
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
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

class _PinResetSuccessScreenState extends State<PinResetSuccessScreen> {
  int _countdown = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Checkmark Circle
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00A79D).withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4ADE80),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                const Text(
                  'PIN Baru Berhasil Dibuat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00A79D),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Subtitle
                const Text(
                  'Anda akan diarahkan ke halaman login dalam 3 detik untuk mencoba PIN Anda!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



