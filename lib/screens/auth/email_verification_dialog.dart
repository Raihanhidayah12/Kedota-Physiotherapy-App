import 'package:flutter/material.dart';
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
  State<EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isError = false;
  String _errorMsg = '';
  int _countdown = 59;
  bool _canResend = false;

  static const _validDummyOtps = {'1234', '5555', '0000', '9999'};

  @override
  void initState() {
    super.initState();
    _sendOtp();
    _otpController.addListener(_onOtpChanged);
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    try {
      setState(() => _isLoading = true);
      
      final svc = SupabaseAuthService();
      await svc.client.auth.signInWithOtp(
        email: widget.email,
        shouldCreateUser: false,
      );

      setState(() {
        _isLoading = false;
        _isError = false;
        _errorMsg = '';
        _countdown = 59;
        _canResend = false;
      });
      
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMsg = 'Failed to send OTP: $e';
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

  void _onOtpChanged() {
    if (_otpController.text.length == 6) {
      _verifyOtp();
    }
    if (mounted) {
      setState(() {
        _isError = false;
        _errorMsg = '';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    
    // For now, use dummy OTP system (can integrate real OTP later)
    if (!_validDummyOtps.contains(otp)) {
      setState(() {
        _isError = true;
        _errorMsg = t(context, 'otpInvalid');
      });
      _otpController.clear();
      return;
    }

    try {
      setState(() => _isLoading = true);

      final svc = SupabaseAuthService();
      final response = await svc.client.auth.verifyOTP(
        email: widget.email,
        token: otp,
        type: OtpType.email,
      );

      if (response.session != null || response.user != null) {
        // Mark email as verified in profiles
        final user = svc.client.auth.currentUser;
        if (user != null) {
          await svc.client
              .from('profiles')
              .update({'email_verified': true})
              .eq('id', user.id);
        }

        if (!mounted) return;
        setState(() => _isLoading = false);
        widget.onVerified();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMsg = 'Verification failed: $e';
      });
      _otpController.clear();
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
                'OTP sent to ${widget.email}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8AA8AC),
                ),
              ),
              const SizedBox(height: 24),

              // OTP Input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  6,
                  (i) => _buildOtpBox(i),
                ),
              ),

              // Error message
              if (_isError) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMsg,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFD94F45),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Resend button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t(context, 'didntReceiveOtp'),
                    style: const TextStyle(fontSize: 13, color: _ink),
                  ),
                  const SizedBox(width: 8),
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
                          style: const TextStyle(
                            fontSize: 13,
                            color: _c500,
                          ),
                        ),
                ],
              ),

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : widget.onCancelled,
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
                      onPressed: _isLoading || _otpController.text.length < 6
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
                                  valueColor: AlwaysStoppedAnimation(_c500),
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
    final char = _otpController.text.length > index
        ? _otpController.text[index]
        : '';
    return Container(
      width: 45,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(
          color: char.isNotEmpty ? _c700 : _c100,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    );
  }
}
