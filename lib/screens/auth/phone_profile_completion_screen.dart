import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/custom_bottom_sheet.dart';
import '../../widgets/custom_date_picker.dart';
import 'phone_create_pin_screen.dart';

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length && i < 8; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(text[i]);
    }

    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class PhoneProfileCompletionScreen extends StatefulWidget {
  final String phoneNumber;

  const PhoneProfileCompletionScreen({super.key, required this.phoneNumber});

  @override
  State<PhoneProfileCompletionScreen> createState() =>
      _PhoneProfileCompletionScreenState();
}

class _PhoneProfileCompletionScreenState
    extends State<PhoneProfileCompletionScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _otpController = TextEditingController();

  DateTime? _selectedBirthDate;
  String? _gender;
  bool _isLoading = false;

  bool _isNameError = false;
  bool _isEmailError = false;
  bool _isDobError = false;
  bool _isGenderError = false;

  // ── Email OTP state ───────────────────────────────────────────────────────
  bool _isEmailVerified = false;
  bool _showOtpField = false;
  bool _isSendingOtp = false;
  bool _isOtpError = false;
  String _otpErrorMsg = '';
  int _otpCountdown = 0;
  int _otpSendCount = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      if (_isNameError && _nameController.text.isNotEmpty) {
        setState(() => _isNameError = false);
      }
    });
    _emailController.addListener(() {
      if (_isEmailError && _emailController.text.isNotEmpty) {
        setState(() => _isEmailError = false);
      }
      // Reset verified state saat email diubah
      if (_isEmailVerified || _showOtpField) {
        setState(() {
          _isEmailVerified = false;
          _showOtpField = false;
          _otpController.clear();
          _isOtpError = false;
          _otpErrorMsg = '';
          _countdownTimer?.cancel();
          _otpCountdown = 0;
        });
      }
    });
    _dobController.addListener(() {
      if (_isDobError && _dobController.text.isNotEmpty) {
        setState(() => _isDobError = false);
      }
      _parseTypedDate(_dobController.text);
    });
    _otpController.addListener(_onOtpChanged);
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // ── OTP Methods ───────────────────────────────────────────────────────────

  void _onOtpChanged() {
    if (mounted) {
      setState(() {
        _isOtpError = false;
        _otpErrorMsg = '';
      });
    }
    if (_otpController.text.length == 6) {
      _verifyEmailOtp();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _otpCountdown = 59);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _otpCountdown--);
      if (_otpCountdown <= 0) t.cancel();
    });
  }

  Future<void> _sendEmailOtp() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _isEmailError = true;
      });
      return;
    }

    if (_otpSendCount >= 3) {
      setState(() {
        _isOtpError = true;
        _otpErrorMsg = t(context, 'otpLimitReached');
      });
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      // Cek email sudah terdaftar tidak
      final emailExists =
          await SupabaseAuthService().checkEmailExists(email);
      if (!mounted) return;
      if (emailExists) {
        setState(() {
          _isSendingOtp = false;
          _isEmailError = true;
        });
        CustomBottomSheet.show(
          context,
          type: BottomSheetType.error,
          title: t(context, 'infoTitle'),
          subtitle: t(context, 'emailAlreadyRegistered'),
          singleButtonText: t(context, 'closeBtn'),
          onSinglePressed: () => Navigator.of(context).pop(),
        );
        return;
      }

      // Kirim OTP via Supabase Auth
      // shouldCreateUser: true karena user belum ada di Supabase Auth
      await SupabaseAuthService().client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );

      _otpSendCount++;
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _showOtpField = true;
        _isOtpError = false;
        _otpErrorMsg = '';
      });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _isOtpError = true;
        _otpErrorMsg = 'Gagal mengirim OTP: $e';
      });
    }
  }

  Future<void> _verifyEmailOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    try {
      final response = await SupabaseAuthService().client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );

      if (!mounted) return;

      if (response.session != null || response.user != null) {
        setState(() {
          _isEmailVerified = true;
          _showOtpField = false;
          _isOtpError = false;
          _otpErrorMsg = '';
          _countdownTimer?.cancel();
        });
      } else {
        setState(() {
          _isOtpError = true;
          _otpErrorMsg = t(context, 'otpInvalid');
        });
        _otpController.clear();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isOtpError = true;
        _otpErrorMsg = t(context, 'otpInvalid');
      });
      _otpController.clear();
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => CustomDatePickerDialog(
        initialDate: _selectedBirthDate ?? DateTime(2000, 1, 1),
        firstDate: DateTime(1920),
        lastDate: now,
        restrictToFutureMonths: false,
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

  Future<void> _submitProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    setState(() {
      _isNameError = name.isEmpty;
      _isEmailError = email.isEmpty || !_isValidEmail(email);
      _isDobError = _selectedBirthDate == null;
      _isGenderError = _gender == null;
    });

    if (_isNameError || _isEmailError || _isDobError || _isGenderError) return;

    // Email harus sudah diverifikasi sebelum lanjut
    if (!_isEmailVerified) {
      if (!_showOtpField) {
        // Belum kirim OTP sama sekali — kirim sekarang
        await _sendEmailOtp();
      } else {
        // OTP sudah dikirim tapi belum diisi / salah
        setState(() {
          _isOtpError = true;
          _otpErrorMsg = t(context, 'emailNotVerifiedYet');
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PhoneCreatePinScreen(
            phone: widget.phoneNumber,
            fullName: name,
            email: email,
            birthDate: _selectedBirthDate!,
            gender: _gender!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: t(context, 'infoTitle'),
        subtitle: errorMessage,
        singleButtonText: t(context, 'closeBtn'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Label field dengan tanda * merah dan pesan error opsional (issue #8)
  Widget _buildFieldLabel(
    String labelText, {
    bool isError = false,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isError)
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text(
              'Isi Terlebih Dahulu',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: labelText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F8),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lengkapi Data Diri',
                      style: TextStyle(
                        color: Color(0xFF00A79D),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pastikan informasi dibawah ini sesuai dengan identitas resmi Anda.',
                      style: TextStyle(
                        color: Color(0xFF667579),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel(
                      'Nama Lengkap',
                      isError: _isNameError,
                      required: false,
                    ),
                    const SizedBox(height: 6),
                    _signupTextInput(
                      controller: _nameController,
                      hint: 'Masukkan Nama Lengkap',
                      hasError: _isNameError,
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel(
                      'Jenis Kelamin',
                      isError: _isGenderError,
                      required: false,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGenderOption(
                            label: t(context, 'male'),
                            value: 'Laki-Laki',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildGenderOption(
                            label: t(context, 'female'),
                            value: 'Perempuan',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel(
                      'Tanggal Lahir',
                      isError: _isDobError,
                      required: false,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.only(left: 12, right: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isDobError
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFE2E8E8),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _dobController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [DateInputFormatter()],
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF334155),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'dd/mm/yyyy',
                                hintStyle: TextStyle(
                                  color: Color(0xFFA0ACAE),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: _pickDate,
                            icon: const Icon(
                              Icons.calendar_month_rounded,
                              color: Color(0xFF00A79D),
                              size: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel('Nomor Telepon', required: false),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E9E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formattedPhoneNumber,
                        style: const TextStyle(
                          color: Color(0xFF5F6B6D),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel(
                      'Email',
                      isError: _isEmailError,
                      required: false,
                    ),
                    const SizedBox(height: 6),
                    // Email field + tombol kirim OTP
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _signupTextInput(
                            controller: _emailController,
                            hint: 'email@gmail.com',
                            hasError: _isEmailError,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: _isEmailVerified,
                            suffixIcon: _isEmailVerified
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF00A79D),
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                        if (!_isEmailVerified) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isSendingOtp ? null : _sendEmailOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF008F86),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSendingOtp
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _showOtpField
                                          ? t(context, 'resendOtp')
                                          : t(context, 'sendOtp'),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Inline OTP field — muncul setelah OTP dikirim
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _showOtpField
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Text(
                                  t(context, 'otpSentToEmail').replaceFirst(
                                    '{email}',
                                    _emailController.text.trim(),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF667579),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // 6-box OTP input
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    6,
                                    (i) => _buildOtpBox(i),
                                  ),
                                ),
                                if (_isOtpError) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _otpErrorMsg,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                // Countdown / Resend
                                Row(
                                  children: [
                                    Text(
                                      t(context, 'didntReceiveOtp'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF667579),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _otpCountdown > 0
                                        ? Text(
                                            t(context, 'resendOtpIn')
                                                .replaceFirst(
                                                  '{time}',
                                                  _otpCountdown
                                                      .toString()
                                                      .padLeft(2, '0'),
                                                ),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF00A79D),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )
                                        : GestureDetector(
                                            onTap: _isSendingOtp
                                                ? null
                                                : _sendEmailOtp,
                                            child: Text(
                                              t(context, 'resendOtp'),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF00A79D),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008F86),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEmailVerified
                                  ? t(context, 'continueBtn')
                                  : _showOtpField
                                      ? t(context, 'verifyAndContinue')
                                      : t(context, 'continueBtn'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF182526),
                        side: const BorderSide(color: Color(0xFF00A79D)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Kembali',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signupTextInput({
    required TextEditingController controller,
    required String hint,
    required bool hasError,
    TextInputType? keyboardType,
    bool readOnly = false,
    Widget? suffixIcon,
  }) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: readOnly ? const Color(0xFFE5E9E8) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: hasError
            ? const Color(0xFFEF4444)
            : readOnly
                ? const Color(0xFF00A79D)
                : Colors.transparent,
        width: readOnly ? 1.5 : 1.0,
      ),
      boxShadow: readOnly
          ? null
          : const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            style: TextStyle(
              fontSize: 13,
              color: readOnly
                  ? const Color(0xFF5F6B6D)
                  : const Color(0xFF334155),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFFA0ACAE),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        if (suffixIcon != null) ...[suffixIcon],
      ],
    ),
  );

  Widget _buildOtpBox(int index) {
    final text = _otpController.text;
    final char = text.length > index ? text[index] : '';
    final isFilled = char.isNotEmpty;
    final isActive = text.length == index;

    return GestureDetector(
      onTap: () {
        // Focus the hidden TextField by requesting focus
      },
      child: Stack(
        children: [
          Container(
            width: 44,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isOtpError
                    ? const Color(0xFFEF4444)
                    : isFilled || isActive
                        ? const Color(0xFF00A79D)
                        : const Color(0xFFE2E8E8),
                width: (isFilled || isActive) ? 2 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              char,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0E2C2F),
              ),
            ),
          ),
          // Hidden TextField untuk menangkap input
          if (index == 0)
            SizedBox(
              width: 44,
              height: 48,
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String get _formattedPhoneNumber {
    var digits = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('62')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    final parts = <String>[];
    if (digits.isNotEmpty) {
      parts.add(digits.substring(0, digits.length < 3 ? digits.length : 3));
      var offset = parts.first.length;
      while (offset < digits.length) {
        final end = (offset + 4 < digits.length) ? offset + 4 : digits.length;
        parts.add(digits.substring(offset, end));
        offset = end;
      }
    }
    return '+62 ${parts.join(' ')}';
  }

  Widget _buildGenderOption({required String label, required String value}) {
    final isSelected = _gender == value;
    final showError = _isGenderError && !isSelected;

    return GestureDetector(
      onTap: () => setState(() {
        _gender = value;
        if (_isGenderError) _isGenderError = false;
      }),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDDF5F2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: showError
                ? const Color(0xFFEF4444)
                : (isSelected
                      ? const Color(0xFF00A79D)
                      : const Color(0xFFE8EEEE)),
            width: (showError || isSelected) ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0B000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 12),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: showError
                    ? const Color(0xFFEF4444)
                    : (isSelected
                          ? const Color(0xFF00A79D)
                          : const Color(0xFFCBD5E1)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: showError
                    ? const Color(0xFFEF4444)
                    : (isSelected
                          ? const Color(0xFF00A79D)
                          : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
