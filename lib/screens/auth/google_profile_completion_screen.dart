import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/custom_bottom_sheet.dart';
import '../../widgets/custom_date_picker.dart';
import 'google_create_pin_screen.dart';

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
  final _dobController = TextEditingController();

  DateTime? _selectedBirthDate;
  String? _gender = 'Laki-Laki';
  bool _agreeTerms = false;
  bool _isLoading = false;

  bool _isNameError = false;
  bool _isDobError = false;
  bool _isGenderError = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialFullName);

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
    _dobController.dispose();
    super.dispose();
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

    setState(() {
      _isNameError = name.isEmpty;
      _isDobError = _selectedBirthDate == null;
      _isGenderError = _gender == null;
    });

    if (_isNameError || _isDobError || _isGenderError) {
      return;
    }

    if (!_agreeTerms) {
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: t(context, 'infoTitle'),
        subtitle: t(context, 'termsRequired'),
        singleButtonText: t(context, 'closeBtn'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GoogleCreatePinScreen(
            phone: '',
            fullName: name,
            email: widget.email,
            birthDate: _selectedBirthDate!,
            gender: _gender!,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: t(context, 'infoTitle'),
        subtitle: t(context, 'saveProfileFailed'),
        singleButtonText: t(context, 'closeBtn'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                    const SizedBox(height: 16),
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
                            side: const BorderSide(
                              color: Color(0xFFCBD5E1),
                              width: 1.5,
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
