import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/notification_service.dart';
import '../../utils/phone_validator.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _bg = Color(0xFFF0F7F7);
const _ink = Color(0xFF0E2C2F);
const _ink2 = Color(0xFF3D6065);
const _ink3 = Color(0xFF8AA8AC);

enum ChangeContactMode { phone, email }

/// 5-step flow for changing phone number or email according to design:
///
/// Change Phone Number Flow:
///   Step 0 — Ubah No. Telepon: displays "Nomor Telepon Sebelumnya" with country code & input.
///            Notice: Verification OTP will be sent to the registered email.
///   Step 1 — Verifikasi OTP: 6 boxes, subtitle "Masukkan 6-digit kode OTP yang telah dikirimkan ke email p*****a@gmail.com".
///   Step 2 — Ubah No. Telepon: displays "Nomor Telepon Baru".
///   Step 3 — Verifikasi OTP: 4 boxes, subtitle "Masukkan 4-digit kode OTP yang telah dikirimkan ke nomor 0857****123".
///   Step 4 — Success screen: "Nomor Telepon Berhasil Diubah", countdown redirect to login.
///
/// Change Email Flow:
///   Step 0 — Ubah Email: displays "Email Sebelumnya".
///            Notice: Verification OTP will be sent to the registered phone number.
///   Step 1 — Verifikasi OTP: 4 boxes, subtitle "Masukkan 4-digit kode OTP yang telah dikirimkan ke nomor 0857****123".
///   Step 2 — Ubah Email: displays "Email Baru".
///   Step 3 — Verifikasi OTP: 6 boxes, subtitle "Masukkan 6-digit kode OTP yang telah dikirimkan ke email p*****a@gmail.com".
///   Step 4 — Success screen: "Email Berhasil Diubah", countdown redirect to login.
class ChangeContactScreen extends StatefulWidget {
  final ChangeContactMode mode;
  final String? currentValue; // pre-filled current phone/email
  final String? currentPhone;
  final String? currentEmail;

  const ChangeContactScreen({
    super.key,
    required this.mode,
    this.currentValue,
    this.currentPhone,
    this.currentEmail,
  });

  @override
  State<ChangeContactScreen> createState() => _ChangeContactScreenState();
}

class _ChangeContactScreenState extends State<ChangeContactScreen>
    with WidgetsBindingObserver {
  final _inputCtr = TextEditingController();
  final _otpCtr = TextEditingController();
  final _inputFocus = FocusNode();
  final _otpFocus = FocusNode();

  int _step = 0; // 0-4
  bool _isLoading = false;
  bool _isError = false;
  String _errorMsg = '';
  bool _isClearingForError = false;
  int _otpCountdown = 59;
  Timer? _countdownTimer;
  int _successCountdown = 3;
  Timer? _successTimer;

  // OTP attempt tracking (max 3 per day)
  int _otpSendCount = 0;
  int _otpVerifyCount = 0;
  DateTime? _lastOtpSendDate;
  DateTime? _lastOtpVerifyDate;

  // Values
  String _currentValue = '';
  String _newValue = '';
  String? _verifiedEmail; // email target for OTP when changing phone
  String? _verifiedPhone; // phone target for OTP when changing email

  // Dummy valid OTPs for phone & email verification
  static const _validDummyOtps = {
    '1234',
    '5555',
    '0000',
    '9999',
    '123456',
    '000000',
    '999999',
  };

  bool get _isPhone => widget.mode == ChangeContactMode.phone;

  // Target OTP destination type:
  // Step 1:
  //   - If changing phone: OTP sent to existing email (6 digits)
  //   - If changing email: OTP sent to existing phone (4 digits)
  // Step 3:
  //   - If changing phone: OTP sent to new phone (4 digits)
  //   - If changing email: OTP sent to new email (6 digits)
  bool get _isCurrentOtpEmail =>
      (_step == 1 && _isPhone) || (_step == 3 && !_isPhone);

  int get _expectedOtpLength => _isCurrentOtpEmail ? 6 : 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial pre-fill for Step 0:
    // If Change Phone: prefill with current phone number
    // If Change Email: prefill with current email
    if (_isPhone) {
      final phone =
          widget.currentPhone ??
          (widget.mode == ChangeContactMode.phone ? widget.currentValue : null);
      if (phone != null && phone.isNotEmpty) {
        _inputCtr.text = phone.replaceFirst(RegExp(r'^\+?62\s*'), '').trim();
      }
      _verifiedEmail = widget.currentEmail;
    } else {
      final email =
          widget.currentEmail ??
          (widget.mode == ChangeContactMode.email ? widget.currentValue : null);
      if (email != null && email.isNotEmpty) {
        _inputCtr.text = email.trim();
      }
      _verifiedPhone = widget.currentPhone;
    }

    _loadOtpLimits();
    _otpCtr.addListener(_onOtpChanged);
    _inputFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _otpFocus.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboardForOtp());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForOtp();
    }
  }

  Future<void> _checkClipboardForOtp() async {
    if (_step != 1 && _step != 3) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) return;

      final match = RegExp(
        r'\b\d{' + _expectedOtpLength.toString() + r'}\b',
      ).firstMatch(text);
      if (match != null) {
        final code = match.group(0)!;
        if (_otpCtr.text != code) {
          if (!mounted) return;
          setState(() {
            _otpCtr.text = code;
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

  Future<void> _loadOtpLimits() async {
    final today = DateTime.now().toUtc();
    _lastOtpSendDate = today;
    _lastOtpVerifyDate = today;
  }

  bool _canSendOtp() {
    final now = DateTime.now().toUtc();
    final today = DateTime(now.year, now.month, now.day);
    final lastSend = _lastOtpSendDate != null
        ? DateTime(
            _lastOtpSendDate!.year,
            _lastOtpSendDate!.month,
            _lastOtpSendDate!.day,
          )
        : null;

    if (lastSend == null || lastSend.isBefore(today)) {
      _otpSendCount = 0;
      _lastOtpSendDate = now;
    }
    return _otpSendCount < 3;
  }

  bool _canVerifyOtp() {
    final now = DateTime.now().toUtc();
    final today = DateTime(now.year, now.month, now.day);
    final lastVerify = _lastOtpVerifyDate != null
        ? DateTime(
            _lastOtpVerifyDate!.year,
            _lastOtpVerifyDate!.month,
            _lastOtpVerifyDate!.day,
          )
        : null;

    if (lastVerify == null || lastVerify.isBefore(today)) {
      _otpVerifyCount = 0;
      _lastOtpVerifyDate = now;
    }
    return _otpVerifyCount < 3;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (_isClearingForError) return;

    if (_otpCtr.text.isNotEmpty && _isError && mounted) {
      setState(() {
        _isError = false;
        _errorMsg = '';
      });
    }

    if (_otpCtr.text.length == _expectedOtpLength && mounted) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    if (!_canVerifyOtp()) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isError = true;
        _errorMsg = t(context, 'otpVerifyLimitReached');
      });
      _isClearingForError = true;
      _otpCtr.clear();
      _isClearingForError = false;
      return;
    }

    final otp = _otpCtr.text.trim();
    if (otp.length != _expectedOtpLength) return;
    bool isValid = false;

    if (_step == 1) {
      if (_isPhone) {
        // Step 1 ganti phone: OTP 6 digit dikirim ke email akun
        isValid = await _verifyEmailOtp(otp) || _validDummyOtps.contains(otp);
      } else {
        // Step 1 ganti email: OTP 4 digit dikirim ke phone akun
        isValid = _validDummyOtps.contains(otp);
      }
    } else {
      if (_isPhone) {
        // Step 3 ganti phone: OTP 4 digit dikirim ke phone baru
        isValid = _validDummyOtps.contains(otp);
      } else {
        // Step 3 ganti email: OTP 6 digit dikirim ke email baru
        isValid = await _verifyEmailOtp(otp) || _validDummyOtps.contains(otp);
      }
    }

    if (!isValid) {
      _otpVerifyCount++;
      _lastOtpVerifyDate = DateTime.now().toUtc();
      HapticFeedback.heavyImpact();
      setState(() {
        _isError = true;
        _errorMsg = t(context, 'otpInvalid');
      });
      _isClearingForError = true;
      _otpCtr.clear();
      _isClearingForError = false;
      return;
    }

    // OTP valid — move to next step
    if (_step == 1) {
      _goToStep(2);
    } else if (_step == 3) {
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

    if (_isPhone) {
      // Input nomor telepon sebelumnya
      if (!PhoneValidator.isValidIndonesianPhone(val)) {
        setState(() {
          _isError = true;
          _errorMsg = t(context, 'validPhoneError');
        });
        return;
      }
      _currentValue = PhoneValidator.normalizePhoneNumber(val);
    } else {
      // Input email sebelumnya
      if (!_isValidEmail(val)) {
        setState(() {
          _isError = true;
          _errorMsg = t(context, 'validEmailError');
        });
        return;
      }
      _currentValue = val;
    }

    setState(() => _isLoading = true);
    try {
      final svc = SupabaseAuthService();
      final user = svc.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final profile = await svc.client
          .from('profiles')
          .select('phone, email, email_verified')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) throw Exception('Profile not found');

      if (_isPhone) {
        // Cek kecocokan Nomor Telepon terdaftar
        final dbPhone = profile['phone']?.toString().trim() ?? '';
        final normalizedDb = PhoneValidator.normalizePhoneNumber(dbPhone);
        final normalizedCurrent = PhoneValidator.normalizePhoneNumber(
          _currentValue,
        );
        if (normalizedDb != normalizedCurrent) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isError = true;
            _errorMsg = t(context, 'phoneNotMatch');
          });
          return;
        }

        // Cek apakah email akun sudah terdaftar dan terverifikasi
        final dbEmail = profile['email']?.toString().trim() ?? '';
        final isEmailVerified = profile['email_verified'] == true;
        if (dbEmail.isEmpty || !isEmailVerified) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isError = true;
            _errorMsg = t(context, 'emailRequiredToChangePhone');
          });
          return;
        }
        _verifiedEmail = dbEmail;
      } else {
        // Cek kecocokan Email terdaftar
        final dbEmail = profile['email']?.toString().trim() ?? '';
        final isEmailVerified = profile['email_verified'] == true;
        if (dbEmail.toLowerCase() != _currentValue.toLowerCase()) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isError = true;
            _errorMsg = t(context, 'emailNotMatch');
          });
          return;
        }

        // Cek apakah email saat ini sudah terverifikasi
        if (!isEmailVerified) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isError = true;
            _errorMsg = t(context, 'emailMustVerifyFirst');
          });
          return;
        }

        // Cek apakah nomor telepon terdaftar untuk menerima OTP
        final dbPhone = profile['phone']?.toString().trim() ?? '';
        if (dbPhone.isEmpty) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isError = true;
            _errorMsg = t(context, 'phoneRequiredToChangeEmail');
          });
          return;
        }
        _verifiedPhone = PhoneValidator.normalizePhoneNumber(dbPhone);
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

      // Kirim OTP verifikasi data lama:
      // Ganti HP -> kirim OTP (6 digit) ke Email saat ini
      // Ganti Email -> kirim OTP (4 digit) ke Nomor HP saat ini
      if (_isPhone) {
        await _sendEmailOtp(_verifiedEmail!);
      } else {
        _otpSendCount++;
        _lastOtpSendDate = DateTime.now().toUtc();
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

    setState(() => _isLoading = true);
    try {
      final svc = SupabaseAuthService();
      final user = svc.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final todayStr = DateTime.now()
          .toUtc()
          .toIso8601String()
          .substring(0, 10);
      final profileCheck = await svc.client
          .from('profiles')
          .select('phone_changed_at, email_changed_at')
          .eq('id', user.id)
          .maybeSingle();

      if (!_isPhone) {
        final phoneChangedAt = profileCheck?['phone_changed_at']?.toString();
        if (phoneChangedAt != null) {
          final d = DateTime.tryParse(phoneChangedAt);
          if (d != null &&
              d.toUtc().toIso8601String().substring(0, 10) == todayStr) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _isError = true;
              _errorMsg = t(context, 'emailBlockedPhoneChangedToday');
            });
            return;
          }
        }
        final emailChangedAt = profileCheck?['email_changed_at']?.toString();
        if (emailChangedAt != null) {
          final d = DateTime.tryParse(emailChangedAt);
          if (d != null &&
              d.toUtc().toIso8601String().substring(0, 10) == todayStr) {
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
        final phoneChangedAt = profileCheck?['phone_changed_at']?.toString();
        if (phoneChangedAt != null) {
          final d = DateTime.tryParse(phoneChangedAt);
          if (d != null &&
              d.toUtc().toIso8601String().substring(0, 10) == todayStr) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _isError = true;
              _errorMsg = t(context, 'phoneChangedTodayLimit');
            });
            return;
          }
        }
        final emailChangedAt = profileCheck?['email_changed_at']?.toString();
        if (emailChangedAt != null) {
          final d = DateTime.tryParse(emailChangedAt);
          if (d != null &&
              d.toUtc().toIso8601String().substring(0, 10) == todayStr) {
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

      // Check uniqueness
      if (_isPhone) {
        final existing = await svc.client
            .from('profiles')
            .select('id')
            .eq('phone', _newValue)
            .neq('id', user.id)
            .maybeSingle();

        if (existing != null) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isError = true;
            _errorMsg = t(context, 'phoneAlreadyRegistered');
          });
          return;
        }
      } else {
        final existing = await svc.client
            .from('profiles')
            .select('id')
            .eq('email', _newValue)
            .neq('id', user.id)
            .maybeSingle();

        if (existing != null) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _isError = true;
            _errorMsg = t(context, 'emailAlreadyRegistered');
          });
          return;
        }
      }

      if (!_canSendOtp()) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMsg = t(context, 'otpLimitReached');
        });
        return;
      }

      // Step 3 OTP to new contact:
      if (_isPhone) {
        _otpSendCount++;
        _lastOtpSendDate = DateTime.now().toUtc();
      } else {
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

  Future<void> _sendEmailOtp(String email) async {
    final svc = SupabaseAuthService();
    await svc.client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
    );
    _otpSendCount++;
    _lastOtpSendDate = DateTime.now().toUtc();
  }

  Future<bool> _verifyEmailOtp(String otp) async {
    final email = (_step == 1 && _isPhone)
        ? (_verifiedEmail ?? _currentValue)
        : _newValue;
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
      NotificationService().showSecurityAlertNotification(
        title: t(context, 'securityAlertContactChangedTitle'),
        body: t(context, 'securityAlertContactChangedBody'),
      );
      _startSuccessCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMsg = e.toString();
      });
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

  String get _otpTarget {
    if (_step == 1) {
      if (_isPhone) {
        return _maskEmail(_verifiedEmail ?? widget.currentEmail ?? '');
      } else {
        return _maskPhone(_verifiedPhone ?? widget.currentPhone ?? '');
      }
    } else {
      if (_isPhone) {
        return _maskPhone(_newValue);
      } else {
        return _maskEmail(_newValue);
      }
    }
  }

  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    return '${phone.substring(0, 4)}****${phone.substring(phone.length - 3)}';
  }

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final name = email.substring(0, at);
    final domain = email.substring(at);
    if (name.length <= 2) return '${name[0]}*$domain';
    return '${name[0]}*****${name[name.length - 1]}$domain';
  }

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
        ? (isNewValue ? t(context, 'contactChangeWarning') : t(context, 'changePhoneSecurityNotice'))
        : (isNewValue ? t(context, 'emailChangeWarning') : t(context, 'changeEmailSecurityNotice'));

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
    return _isPhone ? _buildPhoneField() : _buildEmailField();
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
    final isEmailTarget = _isCurrentOtpEmail;
    final subtitle = isEmailTarget
        ? t(context, 'otpSentToEmail').replaceFirst('{email}', _otpTarget)
        : t(context, 'otpSentToPhone').replaceFirst('{phone}', _otpTarget);

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
            const SizedBox(height: 12),
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
                      if (_isCurrentOtpEmail) {
                        final email = (_step == 1 && _isPhone)
                            ? (_verifiedEmail ?? _currentValue)
                            : _newValue;
                        try {
                          await _sendEmailOtp(email);
                        } catch (e) {
                          setState(() {
                            _isError = true;
                            _errorMsg = 'Failed to resend OTP: $e';
                          });
                          return;
                        }
                      } else {
                        _otpSendCount++;
                        _lastOtpSendDate = DateTime.now().toUtc();
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
                  LengthLimitingTextInputFormatter(_expectedOtpLength),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBoxes() {
    final count = _expectedOtpLength;
    return GestureDetector(
      onTap: () => _otpFocus.requestFocus(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final gap = count == 6 ? 6.0 : 10.0;
          final boxWidth = ((availableWidth - ((count - 1) * gap) - 16) / count)
              .clamp(38.0, 52.0);
          final boxHeight = boxWidth * 1.15;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (index) {
              final filled = index < _otpCtr.text.length;
              final active = index == _otpCtr.text.length;
              final char = filled ? _otpCtr.text[index] : '';

              return Container(
                margin: EdgeInsets.symmetric(horizontal: gap / 2),
                width: boxWidth,
                height: boxHeight,
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
                  style: TextStyle(
                    fontSize: boxWidth * 0.45,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // ── Success step (4) ─────────────────────────────────────────────────────

  Widget _buildSuccess() {
    final msg = _isPhone
        ? t(context, 'phoneChangedSuccess')
        : t(context, 'emailChangedSuccess');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Animated checkmark badge
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A79D).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: _ink2,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(text: t(context, 'redirectingToLoginIn')),
                    TextSpan(
                      text: ' $_successCountdown ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _c500,
                      ),
                    ),
                    TextSpan(text: t(context, 'seconds')),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _redirectToLogin,
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
                  child: Text(t(context, 'loginNow')),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
