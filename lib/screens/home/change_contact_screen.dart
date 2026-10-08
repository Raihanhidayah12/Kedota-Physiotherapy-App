import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/phone_validator.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c100 = Color(0xFFD4F5F3);
const _bg = Color(0xFFF0F7F7);
const _ink = Color(0xFF0E2C2F);
const _ink2 = Color(0xFF3D6065);
const _ink3 = Color(0xFF8AA8AC);

enum ChangeContactMode { phone, email }

/// 5-step flow for changing phone number or email.
///
/// Phone flow:
///   Step 0 — Input current phone (verify identity)
///   Step 1 — OTP to the entered CURRENT phone number
///   Step 2 — Input new phone number
///   Step 3 — OTP to the NEW phone number
///   Step 4 — Success screen → redirect to login
///
/// Email flow:
///   Step 0 — Input current email (verify identity)
///   Step 1 — OTP to the entered CURRENT email
///   Step 2 — Input new email
///   Step 3 — OTP to the NEW email
///   Step 4 — Success screen → redirect to login
class ChangeContactScreen extends StatefulWidget {
  final ChangeContactMode mode;
  final String? currentValue; // pre-filled current phone/email

  const ChangeContactScreen({
    super.key,
    required this.mode,
    this.currentValue,
  });

  @override
  State<ChangeContactScreen> createState() => _ChangeContactScreenState();
}

class _ChangeContactScreenState extends State<ChangeContactScreen> {
  final _inputCtr = TextEditingController();
  final _otpCtr = TextEditingController();
  final _inputFocus = FocusNode();
  final _otpFocus = FocusNode();

  int _step = 0; // 0-4
  bool _isLoading = false;
  bool _isError = false;
  String _errorMsg = '';
  int _otpCountdown = 59;
  Timer? _countdownTimer;
  int _successCountdown = 3;
  Timer? _successTimer;

  // OTP attempt tracking (max 3 per day)
  int _otpSendCount = 0;
  int _otpVerifyCount = 0;
  DateTime? _lastOtpSendDate;
  DateTime? _lastOtpVerifyDate;

  // The value the user typed in step 0 (current) and step 2 (new)
  String _currentValue = '';
  String _newValue = '';

  // Dummy valid OTPs for phone verification (since SMS not implemented yet)
  static const _validDummyOtps = {'1234', '5555', '0000', '9999'};

  bool get _isPhone => widget.mode == ChangeContactMode.phone;

  @override
  void initState() {
    super.initState();
    if (widget.currentValue != null) {
      // Strip +62 prefix (and optional space) for phone pre-fill
      final v = widget.currentValue!;
      _inputCtr.text = _isPhone
          ? v.replaceFirst(RegExp(r'^\+?62\s*'), '').trim()
          : v;
    }
    _loadOtpLimits();
    _otpCtr.addListener(_onOtpChanged);
    _inputFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _otpFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadOtpLimits() async {
    // Load from SharedPreferences or DB
    // For now, reset daily (simplified)
    final today = DateTime.now().toUtc();
    _lastOtpSendDate = today;
    _lastOtpVerifyDate = today;
  }

  bool _canSendOtp() {
    final now = DateTime.now().toUtc();
    final today = DateTime(now.year, now.month, now.day);
    final lastSend = _lastOtpSendDate != null
        ? DateTime(_lastOtpSendDate!.year, _lastOtpSendDate!.month, _lastOtpSendDate!.day)
        : null;

    if (lastSend == null || lastSend.isBefore(today)) {
      // New day — reset counter
      _otpSendCount = 0;
      _lastOtpSendDate = now;
    }
    return _otpSendCount < 3;
  }

  bool _canVerifyOtp() {
    final now = DateTime.now().toUtc();
    final today = DateTime(now.year, now.month, now.day);
    final lastVerify = _lastOtpVerifyDate != null
        ? DateTime(_lastOtpVerifyDate!.year, _lastOtpVerifyDate!.month, _lastOtpVerifyDate!.day)
        : null;

    if (lastVerify == null || lastVerify.isBefore(today)) {
      _otpVerifyCount = 0;
      _lastOtpVerifyDate = now;
    }
    return _otpVerifyCount < 3;
  }

  @override
  void dispose() {
    _inputCtr.dispose();
    _otpCtr.dispose();
    _inputFocus.dispose();
    _otpFocus.dispose();
    _countdownTimer?.cancel();
    _successTimer?.cancel();
    super.dispose();
  }

  // ── OTP helpers ───────────────────────────────────────────────────────────

  void _startCountdown() {
    _otpCountdown = 59;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_otpCountdown > 0) {
          _otpCountdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String get _formattedCountdown {
    final mins = (_otpCountdown ~/ 60).toString().padLeft(2, '0');
    final secs = (_otpCountdown % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _onOtpChanged() {
    if (_otpCtr.text.length == 4 && mounted) {
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
    // Check OTP verify limit first
    if (!_canVerifyOtp()) {
      setState(() {
        _isError = true;
        _errorMsg = t(context, 'otpVerifyLimitReached');
      });
      _otpCtr.clear();
      return;
    }

    final otp = _otpCtr.text.trim();
    bool isValid = false;

    if (_isPhone) {
      // Phone: use dummy OTP system
      isValid = _validDummyOtps.contains(otp);
    } else {
      // Email: verify with Supabase Auth
      isValid = await _verifyEmailOtp(otp);
    }

    if (!isValid) {
      _otpVerifyCount++;
      _lastOtpVerifyDate = DateTime.now().toUtc();
      setState(() {
        _isError = true;
        _errorMsg = t(context, 'otpInvalid');
      });
      _otpCtr.clear();
      return;
    }

    // OTP valid — move to next step
    if (_step == 1) {
      // Verified current identity → go to input new value
      _goToStep(2);
    } else if (_step == 3) {
      // Verified new value → save and show success
      await _saveContact();
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _goToStep(int step) {
    setState(() {
      _step = step;
      _isError = false;
      _errorMsg = '';
      _inputCtr.clear();
      _otpCtr.clear();
      if (step == 1 || step == 3) _startCountdown();
    });
    // Auto-focus appropriate field after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (step == 1 || step == 3) {
        _otpFocus.requestFocus();
      } else {
        _inputFocus.requestFocus();
      }
    });
  }

  Future<void> _onNextStep0() async {
    final val = _inputCtr.text.trim();
    if (val.isEmpty) return;
    if (_isPhone && !PhoneValidator.isValidIndonesianPhone(val)) {
      setState(() {
        _isError = true;
        _errorMsg = t(context, 'validPhoneError');
      });
      return;
    }
    if (!_isPhone && !_isValidEmail(val)) {
      setState(() {
        _isError = true;
        _errorMsg = t(context, 'validEmailError');
      });
      return;
    }
    _currentValue = _isPhone ? PhoneValidator.normalizePhoneNumber(val) : val;

    // Verify that entered current value matches DB
    setState(() => _isLoading = true);
    try {
      final svc = SupabaseAuthService();
      final user = svc.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final profile = await svc.client
          .from('profiles')
          .select(_isPhone ? 'phone' : 'email')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) throw Exception('Profile not found');

      final dbValue = _isPhone
          ? profile['phone']?.toString().trim() ?? ''
          : profile['email']?.toString().trim() ?? '';

      // Normalize both values before comparing for phone
      final normalizedDb = _isPhone
          ? PhoneValidator.normalizePhoneNumber(dbValue)
          : dbValue;
      final normalizedCurrent = _isPhone
          ? PhoneValidator.normalizePhoneNumber(_currentValue)
          : _currentValue;

      if (normalizedDb != normalizedCurrent) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMsg = _isPhone
              ? t(context, 'phoneNotMatch')
              : t(context, 'emailNotMatch');
        });
        return;
      }

      // Check OTP send limit
      if (!_canSendOtp()) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMsg = t(context, 'otpLimitReached');
        });
        return;
      }

      // Send OTP (real for email, dummy for phone)
      if (_isPhone) {
        // Phone SMS not implemented yet - use dummy system
        _otpSendCount++;
        _lastOtpSendDate = DateTime.now().toUtc();
      } else {
        // Email - use Supabase Auth OTP
        await _sendEmailOtp(_currentValue);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      _goToStep(1);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _onNextStep2() async {
    final val = _inputCtr.text.trim();
    if (val.isEmpty) return;
    if (_isPhone && !PhoneValidator.isValidIndonesianPhone(val)) {
      setState(() {
        _isError = true;
        _errorMsg = t(context, 'validPhoneError');
      });
      return;
    }
    if (!_isPhone && !_isValidEmail(val)) {
      setState(() {
        _isError = true;
        _errorMsg = t(context, 'validEmailError');
      });
      return;
    }
    _newValue = _isPhone ? PhoneValidator.normalizePhoneNumber(val) : val;

    // Check if new phone/email is already taken by another user
    setState(() => _isLoading = true);
    try {
      final svc = SupabaseAuthService();
      final user = svc.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Jika ubah email, cek apakah nomor telepon sudah diubah hari ini
      // Jika ubah phone, cek apakah phone atau email sudah diubah hari ini
      final todayStr = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final profileCheck = await svc.client
          .from('profiles')
          .select('phone_changed_at, email_changed_at')
          .eq('id', user.id)
          .maybeSingle();

      if (!_isPhone) {
        // Cek: email tidak boleh diubah kalau phone sudah diubah hari ini
        final phoneChangedAt = profileCheck?['phone_changed_at']?.toString();
        if (phoneChangedAt != null) {
          final d = DateTime.tryParse(phoneChangedAt);
          if (d != null && d.toUtc().toIso8601String().substring(0, 10) == todayStr) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _isError = true;
              _errorMsg = t(context, 'emailBlockedPhoneChangedToday');
            });
            return;
          }
        }
        // Cek: email hanya bisa diubah 1x sehari
        final emailChangedAt = profileCheck?['email_changed_at']?.toString();
        if (emailChangedAt != null) {
          final d = DateTime.tryParse(emailChangedAt);
          if (d != null && d.toUtc().toIso8601String().substring(0, 10) == todayStr) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _isError = true;
              _errorMsg = t(context, 'emailChangedTodayLimit');
            });
            return;
          }
        }
      } else {
        // Cek: phone hanya bisa diubah 1x sehari
        final phoneChangedAt = profileCheck?['phone_changed_at']?.toString();
        if (phoneChangedAt != null) {
          final d = DateTime.tryParse(phoneChangedAt);
          if (d != null && d.toUtc().toIso8601String().substring(0, 10) == todayStr) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _isError = true;
              _errorMsg = t(context, 'phoneChangedTodayLimit');
            });
            return;
          }
        }
        // Cek: phone tidak boleh diubah kalau email sudah diubah hari ini
        final emailChangedAt = profileCheck?['email_changed_at']?.toString();
        if (emailChangedAt != null) {
          final d = DateTime.tryParse(emailChangedAt);
          if (d != null && d.toUtc().toIso8601String().substring(0, 10) == todayStr) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _isError = true;
              _errorMsg = t(context, 'phoneBlockedEmailChangedToday');
            });
            return;
          }
        }
      }

      // Cek apakah nomor/email baru sudah dipakai akun lain
      // Untuk phone: gunakan multi-variant matching karena format bisa berbeda
      dynamic existing;
      if (_isPhone) {
        final digits = _newValue.replaceAll(RegExp(r'\D'), '');
        final variants = [
          '+$digits',                                          // +6282...
          digits,                                             // 6282...
          '0${digits.substring(2)}',                         // 082...
          digits.substring(2),                               // 82...
        ];
        existing = await svc.client
            .from('profiles')
            .select('id')
            .inFilter('phone', variants)
            .maybeSingle();
      } else {
        existing = await svc.client
            .from('profiles')
            .select('id')
            .eq('email', _newValue)
            .maybeSingle();
      }

      if (existing != null && existing['id'] != user.id) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMsg = _isPhone
              ? t(context, 'phoneAlreadyUsed')
              : t(context, 'emailAlreadyUsed');
        });
        return;
      }

      // Check OTP send limit
      if (!_canSendOtp()) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMsg = t(context, 'otpLimitReached');
        });
        return;
      }

      // Send OTP to new value (real for email, dummy for phone)
      if (_isPhone) {
        // Phone SMS not implemented yet - use dummy system
        _otpSendCount++;
        _lastOtpSendDate = DateTime.now().toUtc();
      } else {
        // Email - use Supabase Auth OTP
        await _sendEmailOtp(_newValue);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      _goToStep(3);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMsg = e.toString();
      });
    }
  }

  // ── Email OTP via Supabase Auth ───────────────────────────────────────────

  /// Sends a real OTP to [email] via Supabase Auth (signInWithOtp).
  /// Supabase sends a 6-digit code by email automatically.
  Future<void> _sendEmailOtp(String email) async {
    final svc = SupabaseAuthService();
    await svc.client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false, // don't register new users
    );
    _otpSendCount++;
    _lastOtpSendDate = DateTime.now().toUtc();
  }

  /// Verifies the 6-digit [otp] code for [email] using Supabase Auth verifyOTP.
  /// Returns true if valid, false otherwise.
  Future<bool> _verifyEmailOtp(String otp) async {
    final email = _step == 1 ? _currentValue : _newValue;
    try {
      final svc = SupabaseAuthService();
      final response = await svc.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );
      return response.session != null || response.user != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveContact() async {
    setState(() => _isLoading = true);
    try {
      final svc = SupabaseAuthService();
      final user = svc.client.auth.currentUser;
      if (user != null) {
        if (_isPhone) {
          await svc.client
              .from('profiles')
              .update({
                'phone': _newValue,
                'phone_changed_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', user.id);
        } else {
          await svc.client
              .from('profiles')
              .update({
                'email': _newValue,
                'email_changed_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', user.id);
        }
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = 4;
      });
      _startSuccessCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAppSnackBar(
        context,
        e.toString(),
        type: AppSnackBarType.error,
      );
    }
  }

  void _startSuccessCountdown() {
    _successCountdown = 3;
    _successTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_successCountdown > 1) {
          _successCountdown--;
        } else {
          t.cancel();
          _redirectToLogin();
        }
      });
    });
  }

  Future<void> _redirectToLogin() async {
    await SupabaseAuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
  }

  bool _isValidEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);

  // ── OTP send target string ────────────────────────────────────────────────

  /// The masked destination shown in OTP screen subtitle.
  String get _otpTarget {
    if (_step == 1) {
      return _isPhone ? _maskPhone(_currentValue) : _maskEmail(_currentValue);
    }
    return _isPhone ? _maskPhone(_newValue) : _maskEmail(_newValue);
  }

  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    return '${phone.substring(0, 4)}****${phone.substring(phone.length - 3)}';
  }

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    return '${email[0]}****${email.substring(at)}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_step == 4) return _buildSuccess();
    if (_step == 1 || _step == 3) return _buildOtpStep();
    return _buildInputStep();
  }

  // ── Input step (0 & 2) ───────────────────────────────────────────────────

  Widget _buildInputStep() {
    final isNewValue = _step == 2;
    final title = _isPhone ? t(context, 'changePhone') : t(context, 'changeEmail');
    final sectionLabel = _isPhone
        ? (isNewValue ? t(context, 'newPhoneLabel') : t(context, 'currentPhoneLabel'))
        : (isNewValue ? t(context, 'newEmailLabel') : t(context, 'currentEmailLabel'));
    final warning = _isPhone
        ? t(context, 'contactChangeWarning')
        : t(context, 'emailChangeWarning');

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () {
            if (_step == 0) {
              Navigator.of(context).pop();
            } else {
              _goToStep(0);
            }
          },
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sectionLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink2,
              ),
            ),
            const SizedBox(height: 12),
            _buildInputField(),
            if (_isError) ...[
              const SizedBox(height: 8),
              Text(
                _errorMsg,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFD94F45),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Color(0xFFD4920A),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    warning,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD4920A),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isLoading
                    ? null
                    : (isNewValue ? _onNextStep2 : _onNextStep0),
                style: FilledButton.styleFrom(
                  backgroundColor: _c700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        isNewValue
                            ? t(context, 'saveChanges')
                            : t(context, 'next'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField() {
    if (_isPhone) {
      return _buildPhoneField();
    }
    return _buildEmailField();
  }

  Widget _buildPhoneField() {
    final focused = _inputFocus.hasFocus;
    final borderColor = _isError
        ? const Color(0xFFEF4444)
        : focused
        ? _c500
        : const Color(0xFFDDE4E3);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: focused || _isError ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          ClipOval(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
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
          ),
          const SizedBox(width: 8),
          Text(
            t(context, 'countryCode'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: const Color(0xFFDDE4E3)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _inputCtr,
              focusNode: _inputFocus,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ],
              onChanged: (_) => setState(() {
                _isError = false;
                _errorMsg = '';
              }),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: t(context, 'phoneHint'),
                hintStyle: const TextStyle(color: _ink3, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    final focused = _inputFocus.hasFocus;
    final borderColor = _isError
        ? const Color(0xFFEF4444)
        : focused
        ? _c500
        : const Color(0xFFDDE4E3);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: focused || _isError ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.email_outlined, size: 20, color: _ink3),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _inputCtr,
              focusNode: _inputFocus,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {
                _isError = false;
                _errorMsg = '';
              }),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'nama@email.com',
                hintStyle: const TextStyle(color: _ink3, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  // ── OTP step (1 & 3) ─────────────────────────────────────────────────────

  Widget _buildOtpStep() {
    final subtitle = _isPhone
        ? t(context, 'otpSentToPhone').replaceFirst('{phone}', _otpTarget)
        : t(context, 'otpSentToEmail').replaceFirst('{email}', _otpTarget);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => _goToStep(_step == 1 ? 0 : 2),
        ),
        title: Text(
          t(context, 'otpVerificationTitle'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          children: [
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _ink2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            _buildOtpBoxes(),
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
            const SizedBox(height: 28),
            _otpCountdown > 0
                ? Text(
                    t(context, 'resendOtpIn')
                        .replaceFirst('{time}', _formattedCountdown),
                    style: const TextStyle(
                      fontSize: 13,
                      color: _c500,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : GestureDetector(
                    onTap: () async {
                      if (!_canSendOtp()) {
                        setState(() {
                          _isError = true;
                          _errorMsg = t(context, 'otpLimitReached');
                        });
                        return;
                      }
                      if (_isPhone) {
                        _otpSendCount++;
                        _lastOtpSendDate = DateTime.now().toUtc();
                      } else {
                        // Resend email OTP
                        final email = _step == 1 ? _currentValue : _newValue;
                        try {
                          await _sendEmailOtp(email);
                        } catch (e) {
                          setState(() {
                            _isError = true;
                            _errorMsg = 'Failed to resend OTP: $e';
                          });
                          return;
                        }
                      }
                      _otpCtr.clear();
                      setState(() {
                        _isError = false;
                        _errorMsg = '';
                      });
                      _startCountdown();
                    },
                    child: Text(
                      t(context, 'resendOtp'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: _c500,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: _c500,
                      ),
                    ),
                  ),
            const Spacer(),
            // Hidden number pad trigger — tap boxes to show keyboard
            Opacity(
              opacity: 0,
              child: TextField(
                controller: _otpCtr,
                focusNode: _otpFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBoxes() {
    return GestureDetector(
      onTap: () => _otpFocus.requestFocus(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final filled = index < _otpCtr.text.length;
          final active = index == _otpCtr.text.length;
          final char = filled ? _otpCtr.text[index] : '';

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 44,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isError
                    ? const Color(0xFFD94F45)
                    : active
                    ? _c500
                    : filled
                    ? _c500.withValues(alpha: 0.5)
                    : const Color(0xFFDDE4E3),
                width: active || _isError ? 1.8 : 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _c500.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              char,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Success step (4) ─────────────────────────────────────────────────────

  Widget _buildSuccess() {
    final msg = _isPhone
        ? t(context, 'phoneChangedSuccess')
        : t(context, 'emailChangedSuccess');
    final redirectMsg = t(context, 'redirectLoginIn')
        .replaceFirst('{n}', '$_successCountdown');

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: _c100,
                    shape: BoxShape.circle,
                    border: Border.all(color: _c500, width: 3),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 52,
                    color: _c700,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _c700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  redirectMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _ink2,
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
