import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';

const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);

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
        height: 22,
        decoration: BoxDecoration(
          color: _c500,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

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

class _EmailVerificationDialogState extends State<EmailVerificationDialog>
    with WidgetsBindingObserver {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isLoading = false;
  bool _isError = false;
  String _errorMsg = '';
  int _countdown = 59;
  Timer? _countdownTimer;
  bool _canResend = false;
  int _failedAttempts = 0;
  bool _isLockedOut = false;
  DateTime? _lockoutUntil;
  bool _isClearingForError = false;

  static const _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _otpController.addListener(_checkOtpComplete);
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _sendOtp();
    _checkLockout();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboardForOtp());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForOtp();
    }
  }

  Future<void> _checkClipboardForOtp() async {
    if (_isLockedOut) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) return;

      // Match 6-digit OTP code (Supabase email OTP is 6 digits)
      final match = RegExp(r'\b\d{6}\b').firstMatch(text);
      if (match != null) {
        final code = match.group(0)!;
        if (_otpController.text != code) {
          if (!mounted) return;
          setState(() {
            _otpController.text = code;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP $code terinput otomatis dari clipboard'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _otpController.removeListener(_checkOtpComplete);
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _checkLockout() {
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      setState(() {
        _isLockedOut = true;
        _isError = true;
        _errorMsg = 'Terlalu banyak percobaan gagal. Silakan coba lagi besok.';
      });
    }
  }

  void _recordFailedAttempt() {
    HapticFeedback.heavyImpact();
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
    _isClearingForError = true;
    _otpController.clear();
    _isClearingForError = false;
    if (!_isLockedOut) {
      _focusNode.requestFocus();
    }
  }

  void _checkOtpComplete() {
    if (_isClearingForError) return;

    if (_otpController.text.isNotEmpty) {
      HapticFeedback.selectionClick();
      if (_isError) {
        setState(() {
          _isError = false;
          _errorMsg = '';
        });
      }
    }

    if (_otpController.text.length == 6) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _verifyOtp();
        }
      });
    }
  }

  Future<void> _sendOtp() async {
    try {
      setState(() => _isLoading = true);
      final svc = SupabaseAuthService();
      await svc.client.auth.signInWithOtp(
        email: widget.email,
        shouldCreateUser: true,
      );
      setState(() {
        _isLoading = false;
        _isError = false;
        _errorMsg = '';
        _countdown = 59;
        _canResend = false;
      });
      _startCountdown();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _focusNode.requestFocus();
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
    _countdownTimer?.cancel();
    _countdown = 59;
    _canResend = false;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verifyOtp() async {
    if (_isLockedOut || _isLoading) return;

    final otp = _otpController.text.trim();
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
        final response = await svc.client.auth.verifyOTP(
          email: widget.email,
          token: otp,
          type: OtpType.email,
        );

        if (response.session != null || response.user != null) {
          final user = svc.client.auth.currentUser;
          if (user != null) {
            try {
              await svc.client
                  .from('profiles')
                  .update({'email_verified': true})
                  .eq('id', user.id);
            } catch (dbErr) {
              debugPrint('DB update email_verified failed: $dbErr');
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge Icon matching brand
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCF4F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 30,
                  color: _c500,
                ),
              ),
              const SizedBox(height: 16),

              // Title matching UI OTP No. Telp
              Text(
                t(context, 'verifyOtp'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _c500,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Builder(
                builder: (context) {
                  final template = t(context, 'otpSentToEmail');
                  final parts = template.split('{email}');
                  final prefix = parts.isNotEmpty ? parts[0] : '';
                  final suffix = parts.length > 1 ? parts[1] : '';

                  return RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.45,
                      ),
                      children: [
                        TextSpan(text: prefix),
                        TextSpan(
                          text: widget.email,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (suffix.isNotEmpty) TextSpan(text: suffix),
                        if (!suffix.endsWith('.')) const TextSpan(text: '.'),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Error inline text
              if (_isError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMsg.isNotEmpty ? _errorMsg : t(context, 'otpInvalid'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),

              // 6 OTP boxes matching Phone OTP UI with LayoutBuilder & full paste support
              GestureDetector(
                onTap: () => _focusNode.requestFocus(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 6 boxes with 5 gaps of 8px
                    final availableWidth = constraints.maxWidth;
                    final boxSize = ((availableWidth - (5 * 8)) / 6).clamp(38.0, 52.0);

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final isActive = index == _otpController.text.length;
                        final char = _otpController.text.length > index
                            ? _otpController.text[index]
                            : '';

                        return Container(
                          margin: EdgeInsets.only(right: index == 5 ? 0 : 8),
                          width: boxSize,
                          height: boxSize * 1.15,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _isError
                                  ? const Color(0xFFEF4444)
                                  : (isActive && _focusNode.hasFocus
                                      ? _c500
                                      : (char.isNotEmpty
                                          ? _c700
                                          : const Color(0xFFE2E8F0))),
                              width: _isError || (isActive && _focusNode.hasFocus)
                                  ? 1.8
                                  : 1.2,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (char.isNotEmpty)
                                Text(
                                  char,
                                  style: TextStyle(
                                    fontSize: boxSize * 0.45,
                                    fontWeight: FontWeight.bold,
                                    color: _isError
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF1E293B),
                                  ),
                                )
                              else if (isActive && _focusNode.hasFocus)
                                const _BlinkingCursor(),
                              Positioned(
                                bottom: 8,
                                child: Container(
                                  width: boxSize * 0.35,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: _isError
                                        ? const Color(0xFFEF4444)
                                        : (char.isNotEmpty ||
                                                (isActive && _focusNode.hasFocus)
                                            ? _c500
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

              // Hidden TextField that accepts typing & paste
              SizedBox(
                width: 1,
                height: 1,
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _otpController,
                    focusNode: _focusNode,
                    enabled: !_isLockedOut,
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

              const SizedBox(height: 14),

              // Tombol Tempel OTP
              InkWell(
                onTap: _checkClipboardForOtp,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.content_paste_rounded, size: 16, color: _c500),
                      SizedBox(width: 6),
                      Text(
                        'Tempel OTP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _c500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Resend timer matching Phone OTP UI
              if (_isLoading)
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _c500),
                )
              else if (!_canResend && _countdown > 0)
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      t(context, 'resendIn'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '00:${_countdown.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _c500,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              else
                TextButton(
                  onPressed: _sendOtp,
                  child: Text(
                    t(context, 'resendOtp'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: _c500,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Action buttons: Batal
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onCancelled,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    t(context, 'cancel'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
