import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';

const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c100 = Color(0xFFD4F5F3);
const _ink = Color(0xFF0E2C2F);

class EmailVerificationDialog extends StatefulWidget {
  final String email;
  final VoidCallback onVerified;
  final VoidCallback onCancelled;

  const EmailVerificationDialog({
    super.key,
    required this.email,
    required this.onVerified,
    required this.onCancelled,
  });

  @override
  State<EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog> {
  // 6 controllers + focus nodes, one per digit
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isError = false;
  String _errorMsg = '';
  int _countdown = 59;
  bool _canResend = false;
  int _failedAttempts = 0;
  bool _isLockedOut = false;
  DateTime? _lockoutUntil;

  static const _maxAttempts = 3;

  String get _otpValue =>
      _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _sendOtp();
    _checkLockout();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _checkLockout() {
    if (_lockoutUntil != null &&
        DateTime.now().isBefore(_lockoutUntil!)) {
      setState(() {
        _isLockedOut = true;
        _isError = true;
        _errorMsg = 'Terlalu banyak percobaan gagal. Silakan coba lagi besok.';
      });
    }
  }

  void _recordFailedAttempt() {
    setState(() => _failedAttempts++);
    if (_failedAttempts >= _maxAttempts) {
      setState(() {
        _isLockedOut = true;
        _lockoutUntil = DateTime.now().add(const Duration(days: 1));
        _isError = true;
        _errorMsg =
            'Terlalu banyak percobaan gagal (3x). Silakan coba lagi besok.';
      });
      _clearBoxes();
    }
  }

  void _clearBoxes() {
    for (final c in _controllers) {
      c.clear();
    }
    if (!_isLockedOut) {
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _sendOtp() async {
    try {
      setState(() => _isLoading = true);
      final svc = SupabaseAuthService();
      await svc.client.auth.signInWithOtp(
        email: widget.email,
        shouldCreateUser: true, // needed so Supabase can verify OTP
      );
      setState(() {
        _isLoading = false;
        _isError = false;
        _errorMsg = '';
        _countdown = 59;
        _canResend = false;
      });
      _startCountdown();
      // Auto-focus first box after OTP sent
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _focusNodes[0].requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMsg = 'Gagal mengirim OTP: $e';
      });
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown > 0) {
        _startCountdown();
      } else {
        setState(() => _canResend = true);
      }
    });
  }

  void _onDigitChanged(int index, String value) {
    if (_isLockedOut) return;

    // Clear error on typing
    if (_isError) {
      setState(() {
        _isError = false;
        _errorMsg = '';
      });
    }

    if (value.length == 1) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyOtp();
      }
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      // Go back to previous box on backspace
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _verifyOtp() async {
    if (_isLockedOut) return;

    final otp = _otpValue;
    if (otp.length != 6) {
      setState(() {
        _isError = true;
        _errorMsg = 'OTP harus 6 digit';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final svc = SupabaseAuthService();

      try {
        // Try real Supabase OTP
        final response = await svc.client.auth.verifyOTP(
          email: widget.email,
          token: otp,
          type: OtpType.email,
        );

        if (response.session != null || response.user != null) {
          // Mark email as verified in profiles - use upsert-safe update
          final user = svc.client.auth.currentUser;
          if (user != null) {
            try {
              await svc.client
                  .from('profiles')
                  .update({'email_verified': true})
                  .eq('id', user.id);
            } catch (dbErr) {
              debugPrint('DB update email_verified failed: $dbErr');
              // Column might not exist yet, but OTP was valid - still mark as verified
            }
          }
          if (!mounted) return;
          setState(() => _isLoading = false);
          widget.onVerified();
          return;
        }
      } catch (e) {
        debugPrint('Supabase OTP failed: $e');
        final errMsg = e.toString().toLowerCase();
        // If OTP is actually expired or invalid, show error immediately
        if (errMsg.contains('expired') || errMsg.contains('invalid')) {
          _recordFailedAttempt();
          if (mounted) {
            setState(() {
              _isLoading = false;
              if (!_isLockedOut) {
                _isError = true;
                _errorMsg = 'OTP tidak valid atau sudah kadaluarsa. Kirim ulang OTP.';
              }
            });
            _clearBoxes();
          }
          return;
        }
      }

      // OTP wrong - no fallback, real OTP only
      _recordFailedAttempt();
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (!_isLockedOut) {
            _isError = true;
            _errorMsg = t(context, 'otpInvalid');
          }
        });
        _clearBoxes();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMsg = 'Verifikasi gagal: ${e.toString()}';
      });
      _clearBoxes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                t(context, 'verifyEmailTitle'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'OTP dikirim ke ${widget.email}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF8AA8AC)),
              ),
              const SizedBox(height: 24),

                  // 6 OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _buildOtpBox(i)),
              ),

              // Error message
              if (_isError) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMsg,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFD94F45),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Resend row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t(context, 'didntReceiveOtp'),
                    style: const TextStyle(fontSize: 13, color: _ink),
                  ),
                  const SizedBox(width: 6),
                  _canResend
                      ? GestureDetector(
                          onTap: _sendOtp,
                          child: Text(
                            t(context, 'resendOtp'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: _c500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Text(
                          '${t(context, 'resendOtpIn').replaceFirst('{time}', _countdown.toString())}s',
                          style: const TextStyle(fontSize: 13, color: _c500),
                        ),
                ],
              ),

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : widget.onCancelled,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _c500),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          t(context, 'skipBtn'),
                          style: const TextStyle(color: _c500),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ||
                              _otpValue.length < 6 ||
                              _isLockedOut
                          ? null
                          : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _c700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(_c500),
                                ),
                              )
                            : Text(
                                t(context, 'verify'),
                                style: const TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    final isFilled = _controllers[index].text.isNotEmpty;

    return SizedBox(
      width: 44,
      height: 54,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (e) => _onKeyEvent(index, e),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          enabled: !_isLockedOut,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _c700,
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: isFilled ? _c100 : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isFilled ? _c700 : const Color(0xFFE6EEEE),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _c700, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE6EEEE), width: 2),
            ),
          ),
          onChanged: (v) {
            setState(() {});
            _onDigitChanged(index, v);
          },
        ),
      ),
    );
  }
}
