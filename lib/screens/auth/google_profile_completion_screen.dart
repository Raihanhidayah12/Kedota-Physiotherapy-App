import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  String _gender = 'Laki-Laki';
  bool _agreeTerms = true;
  bool _isLoading = false;

  bool _isNameError = false;
  bool _isPhoneError = false;
  bool _isDobError = false;

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
        setState(() => _isPhoneError = false);
      }
    });
    _dobController.addListener(() {
      if (_isDobError && _dobController.text.isNotEmpty) {
        setState(() => _isDobError = false);
      }
      _parseTypedDate(_dobController.text);
    });
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
    if (digits.startsWith('628')) return digits.length >= 12 && digits.length <= 14;
    if (digits.startsWith('08')) return digits.length >= 11 && digits.length <= 13;
    if (digits.startsWith('8')) return digits.length >= 10 && digits.length <= 12;
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
      _isPhoneError = phoneInput.isEmpty || !_isValidIndonesianPhone(phoneInput);
      _isDobError = _selectedBirthDate == null;
    });

    if (_isNameError || _isPhoneError || _isDobError) {
      return;
    }

    if (!_agreeTerms) {
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: 'Informasi',
        subtitle: 'Silakan menyetujui syarat dan ketentuan yang berlaku.',
        singleButtonText: t(context, 'closeBtn'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
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
        });
        await CustomBottomSheet.show(
          context,
          type: BottomSheetType.error,
          title: t(context, 'phoneAlreadyRegistered'),
          subtitle: t(context, 'phoneAlreadyRegisteredDesc'),
          singleButtonText: t(context, 'closeBtn'),
          onSinglePressed: () => Navigator.of(context).pop(),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phoneNumber: normalizedPhone,
            onVerified: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GoogleCreatePinScreen(
                    phone: normalizedPhone,
                    fullName: name,
                    email: widget.email,
                    birthDate: _selectedBirthDate!,
                    gender: _gender,
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
        title: 'Informasi',
        subtitle: t(context, 'saveProfileFailed'),
        singleButtonText: t(context, 'closeBtn'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
    }
  }

  Widget _buildFieldLabel(String labelText, {bool isError = false}) {
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
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
      backgroundColor: const Color(0xFFF7F9F9),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Logo Header Top
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Image.asset(
                    'assets/image/logo 2.png',
                    height: 52,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
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

            // White Card Container Bottom
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lengkapi Data Diri',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pastikan informasi dibawah ini sesuai dengan identitas resmi Anda.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Nama Lengkap
                      _buildFieldLabel('Nama Lengkap', isError: _isNameError),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isNameError
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFE2E8F0),
                            width: _isNameError ? 1.5 : 1.0,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Masukkan Nama Lengkap',
                            hintStyle: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Jenis Kelamin
                      _buildFieldLabel('Jenis Kelamin'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGenderOption(
                              label: 'Laki-Laki',
                              value: 'Laki-Laki',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildGenderOption(
                              label: 'Perempuan',
                              value: 'Perempuan',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tanggal Lahir
                      _buildFieldLabel('Tanggal Lahir', isError: _isDobError),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isDobError
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFE2E8F0),
                            width: _isDobError ? 1.5 : 1.0,
                          ),
                        ),
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _dobController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [DateInputFormatter()],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'dd/mm/yyyy',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _pickDate,
                              icon: const Icon(
                                Icons.calendar_today_rounded,
                                color: Color(0xFF00A79D),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Nomor Telepon Input
                      _buildFieldLabel('No. Telp', isError: _isPhoneError),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isPhoneError
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFE2E8F0),
                            width: _isPhoneError ? 1.5 : 1.0,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          decoration: const InputDecoration(
                            hintText: '08XX XXXX XXXX',
                            hintStyle: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email (Readonly dari Google)
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          widget.email,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Checkbox Syarat & Ketentuan
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreeTerms,
                              activeColor: const Color(0xFF00A79D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _agreeTerms = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Saya setuju dengan syarat dan ketentuan yang berlaku.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Tombol Lanjut
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A79D),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Lanjut',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tombol Kembali
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1E293B),
                            side: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Kembali',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
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

  Widget _buildGenderOption({
    required String label,
    required String value,
  }) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE8F6F4)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00A79D)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF00A79D)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF00A79D)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
