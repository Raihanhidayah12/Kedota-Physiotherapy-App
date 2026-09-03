import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/custom_bottom_sheet.dart';
import 'pin_verification_screen.dart';
import 'phone_profile_completion_screen.dart';
import '../errors/otp_rate_limit_screen.dart';

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
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

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String? pin;
  final VoidCallback? onVerified;
  final bool isDormant;
  final String? targetEmail;
  final bool showStepIndicator;
  final int activeStep;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.pin,
    this.onVerified,
    this.isDormant = false,
    this.targetEmail,
    this.showStepIndicator = false,
    this.activeStep = 2,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _timer;
  int _secondsRemaining = 59;
  bool _isError = false;
  int _failedAttempts = 0;

  static const _validDummyOtps = {'1234', '5555', '0000', '9999'};

  Widget _buildStepIndicator(int activeStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
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

  @override
  void initState() {
    super.initState();
    _startTimer();
    _otpController.addListener(_checkOtpComplete);
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _checkOtpComplete() {
    if (_otpController.text.isNotEmpty) {
      HapticFeedback.selectionClick();
    }
    if (_otpController.text.length == 4) {
      Future.delayed(const Duration(milliseconds: 300), () {
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

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}*@$domain';
    }
    return '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}@$domain';
  }

  void _showDormantAccountDialog({
    required String phoneNumber,
    required String email,
  }) {
    final maskedEmail = _maskEmail(email);
    CustomBottomSheet.show(
      context,
      type: BottomSheetType.error,
      title: t(context, 'dormantAccountTitle'),
      subtitle:
          '${t(context, 'dormantAccountSubtitle')}\n\nEmail: $maskedEmail',
      primaryButtonText: t(context, 'continueEmail'),
      onPrimaryPressed: () {
        Navigator.of(context).pop();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: phoneNumber,
              isDormant: true,
              targetEmail: email,
              onVerified: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) =>
                        PinVerificationScreen(phoneNumber: phoneNumber),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
          (route) => false,
        );
      },
      secondaryButtonText: t(context, 'cancel'),
      onSecondaryPressed: () => Navigator.of(context).pop(),
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (_validDummyOtps.contains(otp)) {
      if (widget.onVerified != null) {
        widget.onVerified!.call();
      } else {
        try {
          final accountResult = await SupabaseAuthService().checkAccountStatus(
            widget.phoneNumber.replaceAll(RegExp(r'\D'), ''),
          );

          if (!mounted) return;

          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              if (accountResult.isDormant) {
                _showDormantAccountDialog(
                  phoneNumber: widget.phoneNumber,
                  email: accountResult.email ?? '',
                );
              } else if (accountResult.isRegistered) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        PinVerificationScreen(phoneNumber: widget.phoneNumber),
                  ),
                );
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => PhoneProfileCompletionScreen(
                      phoneNumber: widget.phoneNumber,
                    ),
                  ),
                );
              }
            }
          });
        } catch (e) {
          debugPrint('Error checking account status: $e');
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => PhoneProfileCompletionScreen(
                    phoneNumber: widget.phoneNumber,
                  ),
                ),
              );
            }
          });
        }
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
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedPhone = _formatPhoneNumber(widget.phoneNumber);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
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
            ).animate().fade(duration: 500.ms).slideY(begin: 0.2, curve: Curves.easeOutQuad),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    children: [
                      if (widget.showStepIndicator) ...[
                        _buildStepIndicator(widget.activeStep),
                        const SizedBox(height: 18),
                      ],
                      Text(
                        t(context, 'verifyOtp'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF00A79D),
                        ),
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                            height: 1.45,
                          ),
                          children: [
                            TextSpan(
                              text: t(context, 'enterOtpSentTo'),
                            ),
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
                      const SizedBox(height: 16),
                      // Teks error inline jika OTP salah
                      if (_isError)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Kode OTP tidak sesuai silakan coba lagi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: () => _focusNode.requestFocus(),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final boxSize = ((constraints.maxWidth - 36) / 4)
                                  .clamp(0.0, 72.0);
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(4, (index) {
                                  final isActive =
                                      index == _otpController.text.length;
                                  final char =
                                      _otpController.text.length > index
                                          ? _otpController.text[index]
                                          : "";

                                  return Container(
                                    margin: EdgeInsets.only(
                                      right: index == 3 ? 0 : 12,
                                    ),
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
                                        width: _isError ||
                                                (isActive &&
                                                    _focusNode.hasFocus)
                                            ? 1.5
                                            : 1.0,
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (char.isNotEmpty)
                                          Text(
                                            char,
                                            style: TextStyle(
                                              fontSize: boxSize * 0.4,
                                              fontWeight: FontWeight.bold,
                                              color: _isError
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF1E293B),
                                            ),
                                          )
                                        else if (isActive &&
                                            _focusNode.hasFocus)
                                          const _BlinkingCursor(),
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
                                                                _focusNode
                                                                    .hasFocus)
                                                        ? const Color(
                                                            0xFF00A79D)
                                                        : const Color(
                                                            0xFFCBD5E1)),
                                              borderRadius:
                                                  BorderRadius.circular(1),
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
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          if (_secondsRemaining > 0) ...[
                            Text(
                              t(context, 'resendIn'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF00A79D),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ] else ...[
                            TextButton(
                              onPressed: () {
                                _startTimer();
                                CustomBottomSheet.show(
                                  context,
                                  type: BottomSheetType.success,
                                  title: t(context, 'otpSentTitle'),
                                  subtitle: t(context, 'otpResent'),
                                  singleButtonText:
                                      t(context, 'close'),
                                  onSinglePressed: () =>
                                      Navigator.of(context).pop(),
                                );
                              },
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
                        ],
                      ),
                    ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
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
