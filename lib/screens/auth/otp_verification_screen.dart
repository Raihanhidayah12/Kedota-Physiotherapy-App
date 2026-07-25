import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_language.dart';
import '../../widgets/language_button.dart';
import '../../widgets/language_button.dart';
import '../home/home_screen.dart';
import '../errors/otp_rate_limit_screen.dart';
import 'pin_verification_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String? pin;
  final VoidCallback? onVerified;
  final bool isDormant;
  final String? targetEmail;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.pin,
    this.onVerified,
    this.isDormant = false,
    this.targetEmail,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _isError = false;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Listen untuk auto-submit setelah OTP diinput penuh (6 digit)
    _otpController.addListener(_checkOtpComplete);
  }

  void _checkOtpComplete() {
    if (_otpController.text.isNotEmpty) {
      HapticFeedback.selectionClick();
    }
    if (_otpController.text.length == 4) {
      // Auto-submit setelah 500ms
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _verifyOtp();
        }
      });
    } else {
      if (_isError) {
        setState(() => _isError = false);
      }
    }
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
    _secondsRemaining = 60;
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

  static const _validDummyOtps = {'1234', '5555', '0000', '9999'};

  void _verifyOtp() {
    final otp = _otpController.text.trim();
    // Accept strictly only the 4 specified dummy OTP codes: 1234, 5555, 0000, 9999
    if (_validDummyOtps.contains(otp)) {
      if (widget.onVerified != null) {
        widget.onVerified!.call();
      } else {
        // Auto-submit and navigate to Pin Screen
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PinVerificationScreen(phoneNumber: widget.phoneNumber),
              ),
            );
          }
        });
      }
      return;
    }

    setState(() {
      _isError = true;
      _failedAttempts++;
      _otpController.clear();
    });

    if (_failedAttempts >= 3) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OtpRateLimitScreen(phoneNumber: widget.phoneNumber),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    final String codeSentText;
    if (widget.isDormant && widget.targetEmail != null) {
      codeSentText = t(
        context,
        'sentEmailCode',
      ).replaceAll('{email}', widget.targetEmail!);
    } else {
      codeSentText = t(
        context,
        'sentCode',
      ).replaceAll('{phone}', widget.phoneNumber);
    }
    final otpStatusText = _secondsRemaining > 0
        ? t(
            context,
            'otpExpires',
          ).replaceAll('{seconds}', _secondsRemaining.toString())
        : t(context, 'otpExpired');

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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  color: const Color(0xFF17324D),
                                  tooltip: t(context, 'back'),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.72,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                LanguageButton(),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (widget.pin != null)
                              Text(
                                t(
                                  context,
                                  'pinCreated',
                                ).replaceAll('{pin}', widget.pin ?? ''),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF00A79D),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              t(context, 'verifyPhone'),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF17324D),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              codeSentText,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: () {
                                _focusNode.requestFocus();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(4, (index) {
                                    final isActive = index == _otpController.text.length;
                                    final char = _otpController.text.length > index
                                        ? _otpController.text[index]
                                        : "";
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                      width: 56,
                                      height: 64,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _isError
                                            ? Colors.red.withValues(alpha: 0.1)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _isError
                                              ? Colors.red
                                              : (isActive
                                                  ? const Color(0xFF00A79D)
                                                  : const Color(0xFFDCE7F5)),
                                          width: isActive || _isError ? 2 : 1,
                                        ),
                                      ),
                                      child: Text(
                                        char,
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: _isError
                                              ? Colors.red
                                              : const Color(0xFF17324D),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            if (_isError)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    t(context, 'otpInvalid'),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: 1,
                              height: 1,
                              child: Opacity(
                                opacity: 0,
                                child: TextField(
                                  controller: _otpController,
                                  focusNode: _focusNode,
                                  keyboardType: TextInputType.number,
                                  autofocus: true,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              otpStatusText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _secondsRemaining > 0
                                    ? _verifyOtp
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF00A79D),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  t(context, 'verifyOtp'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  _startTimer();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(t(context, 'otpResent')),
                                    ),
                                  );
                                },
                                child: Text(
                                  t(context, 'resendOtp'),
                                  style: const TextStyle(
                                    color: Color(0xFF00A79D),
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
