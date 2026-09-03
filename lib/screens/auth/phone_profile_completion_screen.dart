import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  const PhoneProfileCompletionScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<PhoneProfileCompletionScreen> createState() =>
      _PhoneProfileCompletionScreenState();
}

class _PhoneProfileCompletionScreenState
    extends State<PhoneProfileCompletionScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();

  DateTime? _selectedBirthDate;
  String _gender = 'Laki-Laki';
  bool _agreeTerms = true;
  bool _isLoading = false;

  bool _isNameError = false;
  bool _isEmailError = false;
  bool _isDobError = false;

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
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
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
    final email = _emailController.text.trim();

    setState(() {
      _isNameError = name.isEmpty;
      _isEmailError = email.isEmpty || !_isValidEmail(email);
      _isDobError = _selectedBirthDate == null;
    });

    if (_isNameError || _isEmailError || _isDobError) return;

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

    setState(() => _isLoading = true);

    try {
      final emailExists = await SupabaseAuthService().checkEmailExists(email);

      if (!mounted) return;

      if (emailExists) {
        setState(() {
          _isLoading = false;
          _isEmailError = true;
        });
        CustomBottomSheet.show(
          context,
          type: BottomSheetType.error,
          title: 'Informasi',
          subtitle: t(context, 'emailAlreadyRegistered'),
          singleButtonText: t(context, 'closeBtn'),
          onSinglePressed: () => Navigator.of(context).pop(),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PhoneCreatePinScreen(
            phone: widget.phoneNumber,
            fullName: name,
            email: email,
            birthDate: _selectedBirthDate!,
            gender: _gender,
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
        title: 'Informasi',
        subtitle: errorMessage,
        singleButtonText: t(context, 'closeBtn'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Label field dengan tanda * merah dan pesan error opsional (issue #8)
  Widget _buildFieldLabel(String labelText, {bool isError = false, bool required = true}) {
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
      backgroundColor: const Color(0xFFF7F9F9),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Logo Header
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

            // White Card
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
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
                        'Pastikan informasi di bawah ini sesuai dengan identitas resmi Anda.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Nama Lengkap ──
                      _buildFieldLabel('Nama Lengkap', isError: _isNameError),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isNameError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
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
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Jenis Kelamin ──
                      _buildFieldLabel('Jenis Kelamin'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildGenderOption(label: 'Laki-Laki', value: 'Laki-Laki')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildGenderOption(label: 'Perempuan', value: 'Perempuan')),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Tanggal Lahir — ketik atau klik ikon kalender (issue #6 & #10) ──
                      _buildFieldLabel('Tanggal Lahir', isError: _isDobError),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isDobError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
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
                                  hintText: 'DD/MM/YYYY',  // issue #10 — kapital
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 14),
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

                      // ── No. Telp (readonly) ──
                      _buildFieldLabel('No. Telp', required: false),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          widget.phoneNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Email ──
                      _buildFieldLabel('Email', isError: _isEmailError),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isEmailError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                            width: _isEmailError ? 1.5 : 1.0,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Masukkan Email',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Checkbox T&C ──
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
                                if (val != null) setState(() => _agreeTerms = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Saya setuju dengan syarat dan ketentuan yang berlaku.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Tombol Lanjut dengan gradient ──
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF007F78), Color(0xFF00A79D)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
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
                      ),
                      const SizedBox(height: 12),

                      // ── Tombol Kembali ──
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1E293B),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
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

  Widget _buildGenderOption({required String label, required String value}) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F6F4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF00A79D) : const Color(0xFFE2E8F0),
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
                color: isSelected ? const Color(0xFF00A79D) : const Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF00A79D) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
