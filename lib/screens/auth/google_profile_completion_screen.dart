import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/custom_bottom_sheet.dart';
import '../../widgets/custom_date_picker.dart';
import 'google_create_pin_screen.dart';
import 'otp_verification_screen.dart';

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length && i < 8; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      buffer.write(text[i]);
    }

    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class GoogleProfileCompletionScreen extends StatefulWidget {
  final String email;
  final String initialFullName;
  final String initialPhone;
  final String initialBirthDateStr;

  const GoogleProfileCompletionScreen({
    super.key,
    required this.email,
    this.initialFullName = '',
    this.initialPhone = '',
    this.initialBirthDateStr = '',
  });

  @override
  State<GoogleProfileCompletionScreen> createState() =>
      _GoogleProfileCompletionScreenState();
}

class _GoogleProfileCompletionScreenState
    extends State<GoogleProfileCompletionScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _dobController = TextEditingController();

  DateTime? _selectedBirthDate;
  String? _gender = 'Laki-Laki';
  bool _isLoading = false;

  bool _isNameError = false;
  bool _isPhoneError = false;
  String? _phoneCustomError;
  bool _isDobError = false;
  bool _isGenderError = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialFullName);
    _phoneController = TextEditingController(text: widget.initialPhone);

    if (widget.initialBirthDateStr.isNotEmpty) {
      _selectedBirthDate = DateTime.tryParse(widget.initialBirthDateStr);
      if (_selectedBirthDate != null) {
        _dobController.text =
            '${_selectedBirthDate!.day.toString().padLeft(2, '0')}/${_selectedBirthDate!.month.toString().padLeft(2, '0')}/${_selectedBirthDate!.year}';
      }
    }

    _nameController.addListener(() {
      if (_isNameError && _nameController.text.isNotEmpty) {
        setState(() => _isNameError = false);
      }
    });
    _phoneController.addListener(() {
      if (_isPhoneError && _phoneController.text.isNotEmpty) {
        setState(() {
          _isPhoneError = false;
          _phoneCustomError = null;
        });
      }
    });
    _dobController.addListener(() {
      if (_isDobError && _dobController.text.isNotEmpty) {
        setState(() => _isDobError = false);
      }
      _parseTypedDate(_dobController.text);
    });
  }

  Widget _buildIndonesianFlag() {
    return ClipOval(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
        ),
        child: Column(
          children: [
            Expanded(child: Container(color: const Color(0xFFCE1126))),
            Expanded(child: Container(color: Colors.white)),
          ],
        ),
      ),
    );
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
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  String _normalizePhoneNumber(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('62')) return '+$digits';
    if (digits.startsWith('0')) return '+62${digits.substring(1)}';
    if (digits.startsWith('8')) return '+62$digits';
    return '+62$digits';
  }

  bool _isValidIndonesianPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;
    if (digits.startsWith('628')) {
      return digits.length >= 12 && digits.length <= 14;
    }
    if (digits.startsWith('08')) {
      return digits.length >= 11 && digits.length <= 13;
    }
    if (digits.startsWith('8')) {
      return digits.length >= 10 && digits.length <= 12;
    }
    return false;
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
    final phoneInput = _phoneController.text.trim();

    setState(() {
      _isNameError = name.isEmpty;
      _isPhoneError =
          phoneInput.isEmpty || !_isValidIndonesianPhone(phoneInput);
      _phoneCustomError = phoneInput.isEmpty
          ? null
          : (!_isValidIndonesianPhone(phoneInput)
              ? t(context, 'validPhoneError')
              : null);
      _isDobError = _selectedBirthDate == null;
      _isGenderError = _gender == null;
    });

    if (_isNameError || _isPhoneError || _isDobError || _isGenderError) {
      return;
    }

    final normalizedPhone = _normalizePhoneNumber(phoneInput);
    setState(() => _isLoading = true);

    try {
      final phoneExists = await SupabaseAuthService().checkPhoneExists(
        normalizedPhone,
      );

      if (!mounted) return;

      if (phoneExists) {
        setState(() {
          _isLoading = false;
          _isPhoneError = true;
          _phoneCustomError = t(context, 'phoneAlreadyRegistered');
        });
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phoneNumber: normalizedPhone,
            onVerified: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => GoogleCreatePinScreen(
                    phone: normalizedPhone,
                    fullName: name,
                    email: widget.email,
                    birthDate: _selectedBirthDate!,
                    gender: _gender!,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: t(context, 'infoTitle'),
        subtitle: t(context, 'saveProfileFailed'),
        singleButtonText: t(context, 'closeBtn'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
    }
  }

  /// Label field dengan tanda * merah dan pesan error opsional
  Widget _buildFieldLabel(
    String labelText, {
    bool isError = false,
    String? errorMessage,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isError)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              errorMessage ?? 'Isi Terlebih Dahulu',
              style: const TextStyle(
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

  Widget _signupTextInput({
    required TextEditingController controller,
    required String hint,
    required bool hasError,
    TextInputType? keyboardType,
  }) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: hasError ? const Color(0xFFEF4444) : Colors.transparent,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
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
  );

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

  Widget _buildPhoneInput() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isPhoneError ? const Color(0xFFEF4444) : Colors.transparent,
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
          _buildIndonesianFlag(),
          const SizedBox(width: 8),
          const Text(
            '+62',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 18,
            color: const Color(0xFFE2E8E8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ],
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              decoration: InputDecoration(
                hintText: t(context, 'phoneHint'),
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
        ],
      ),
    );
  }

  Future<void> _handleBack() async {
    final shouldExit = await CustomBottomSheet.show<bool>(
      context,
      type: BottomSheetType.info,
      title: t(context, 'cancelRegistrationTitle'),
      subtitle: t(context, 'cancelRegistrationDesc'),
      secondaryButtonText: t(context, 'exitRegistration'),
      onSecondaryPressed: () => Navigator.of(context).pop(true),
      primaryButtonText: t(context, 'continueRegistration'),
      onPrimaryPressed: () => Navigator.of(context).pop(false),
      isDismissible: false,
      enableDrag: false,
    );

    if (shouldExit == true && mounted) {
      await SupabaseAuthService().signOut();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
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
                    Text(
                      t(context, 'registerAccountTitle'),
                      style: const TextStyle(
                        color: Color(0xFF00A79D),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t(context, 'registerAccountDesc'),
                      style: const TextStyle(
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
                    _buildFieldLabel(
                      'Nomor Telepon',
                      isError: _isPhoneError,
                      errorMessage: _phoneCustomError,
                      required: false,
                    ),
                    const SizedBox(height: 6),
                    _buildPhoneInput(),
                    const SizedBox(height: 16),
                    _buildFieldLabel(
                      'Email',
                      required: false,
                    ),
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
                        widget.email,
                        style: const TextStyle(
                          color: Color(0xFF5F6B6D),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                          : const Text(
                              'Lanjut',
                              style: TextStyle(
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
                      onPressed: _handleBack,
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
    ),
  );
  }
}
