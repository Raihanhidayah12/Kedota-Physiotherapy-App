import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/custom_bottom_sheet.dart';
import 'pin_verification_screen.dart';
import 'phone_profile_completion_screen.dart';
import '../errors/otp_rate_limit_screen.dart';

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
  int _secondsRemaining = 59;
  bool _isError = false;
  int _failedAttempts = 0;

  static const _validDummyOtps = {'123456', '555555', '000000', '999999'};

  Widget _buildStepIndicator(int activeStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
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
  }

  void _checkOtpComplete() {
    if (_otpController.text.isNotEmpty) {
      HapticFeedback.selectionClick();
    }
    if (_otpController.text.length == 6) {
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
        // pushAndRemoveUntil agar tidak ada context lama yang tersisa
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

    CustomBottomSheet.show(
      context,
      type: BottomSheetType.error,
      title: 'Kode Salah',
      subtitle: 'Kode OTP tidak sesuai. Silakan coba lagi.',
      singleButtonText: 'Coba Lagi',
      onSinglePressed: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedPhone = _formatPhoneNumber(widget.phoneNumber);

    return Scaffold(
      backgroundColor: const Color(0xFFE8F6F4),
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
            ),
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
                      _buildStepIndicator(2),
                      const SizedBox(height: 18),
                      const Text(
                        'Verifikasi OTP',
                        style: TextStyle(
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
                            const TextSpan(
                              text:
                                  'Masukkan 6 digit kode OTP yang telah dikirimkan ke nomor ',
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
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => _focusNode.requestFocus(),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              final isActive =
                                  index == _otpController.text.length;
                              final char = _otpController.text.length > index
                                  ? _otpController.text[index]
                                  : "";

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                width: 50,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isError
                                        ? const Color(0xFFEF4444)
                                        : (isActive
                                              ? const Color(0xFF00A79D)
                                              : const Color(0xFFE2E8F0)),
                                    width: _isError || isActive ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      char,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: _isError
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      child: Container(
                                        width: 18,
                                        height: 2,
                                        decoration: BoxDecoration(
                                          color: _isError
                                              ? const Color(0xFFEF4444)
                                              : (char.isNotEmpty || isActive
                                                    ? const Color(0xFF00A79D)
                                                    : const Color(0xFFCBD5E1)),
                                          borderRadius: BorderRadius.circular(
                                            1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
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
                              LengthLimitingTextInputFormatter(6),
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
                            const Text(
                              'Kirim Ulang Dalam ',
                              style: TextStyle(
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
                                  title: 'Kode OTP Dikirim',
                                  subtitle: t(context, 'otpResent'),
                                  singleButtonText:
                                      t(context, 'close') ?? 'Tutup',
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
