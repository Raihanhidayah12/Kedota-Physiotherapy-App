import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/custom_bottom_sheet.dart';
import '../../widgets/language_button.dart';
import '../home/home_screen.dart';
import 'google_create_pin_screen.dart';

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

  DateTime? _selectedBirthDate;
  String _gender = 'Laki-laki';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialFullName);
    _phoneController = TextEditingController(text: widget.initialPhone);

    if (widget.initialBirthDateStr.isNotEmpty) {
      _selectedBirthDate = DateTime.tryParse(widget.initialBirthDateStr);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        elevation: 10,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00A79D).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: const Color(0xFF00A79D),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF17324D),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

    // Format: 628xxxxxxxxx (11-13 digits after 62)
    if (digits.startsWith('628')) {
      return digits.length >= 12 && digits.length <= 14;
    }

    // Format: 08xxxxxxxxx (10-12 digits)
    if (digits.startsWith('08')) {
      return digits.length >= 11 && digits.length <= 13;
    }

    // Format: 8xxxxxxxxx (9-11 digits without 0 or country code)
    if (digits.startsWith('8')) {
      return digits.length >= 10 && digits.length <= 12;
    }

    return false;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00A79D),
              onPrimary: Colors.white,
              onSurface: Color(0xFF17324D),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  Future<void> _submitProfile() async {
    final name = _nameController.text.trim();
    final phoneInput = _phoneController.text.trim();

    if (name.isEmpty) {
      _showModernSnackBar(t(context, 'fullNameRequired'), isError: true);
      return;
    }

    if (phoneInput.isEmpty) {
      _showModernSnackBar(t(context, 'enterPhoneError'), isError: true);
      return;
    }

    if (!_isValidIndonesianPhone(phoneInput)) {
      _showModernSnackBar(t(context, 'validPhoneError'), isError: true);
      return;
    }

    if (_selectedBirthDate == null) {
      _showModernSnackBar(t(context, 'selectBirthDateError'), isError: true);
      return;
    }

    final normalizedPhone = _normalizePhoneNumber(phoneInput);

    // Navigate to PIN creation screen
    await Navigator.of(context).push(
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
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;

    String dateText = _selectedBirthDate != null
        ? '${_selectedBirthDate!.day.toString().padLeft(2, '0')}/${_selectedBirthDate!.month.toString().padLeft(2, '0')}/${_selectedBirthDate!.year}'
        : t(context, 'selectBirthDateHint');

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEAF7F4),
                  Color(0xFFF8FBFF),
                  Color(0xFFF5EFFF),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 16 : 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          isCompact ? 18 : 24,
                          24,
                          isCompact ? 18 : 24,
                          24,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.62),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7F9CCB).withValues(alpha: 0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF4285F4).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.g_mobiledata_rounded,
                                        color: Color(0xFF4285F4),
                                        size: 22,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Google Auth',
                                        style: TextStyle(
                                          color: Color(0xFF4285F4),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox.shrink(), // Language button hidden - will be in settings
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              t(context, 'googleProfileTitle'),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF17324D),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t(context, 'googleProfileDesc'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF6B8092),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Email (Readonly Google badge)
                            Text(
                              t(context, 'email'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF17324D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFEFF4).withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.email_outlined,
                                    color: Color(0xFF6B8092),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      widget.email,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF17324D),
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF00A79D),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Full Name
                            Text(
                              t(context, 'fullName'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF17324D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF17324D),
                              ),
                              decoration: InputDecoration(
                                hintText: t(context, 'fullNameExample'),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.72),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF00A79D),
                                    width: 1.8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Phone Number
                            Text(
                              t(context, 'phoneNumber'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF17324D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF17324D),
                              ),
                              decoration: InputDecoration(
                                hintText: t(context, 'phoneExample'),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.72),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF00A79D),
                                    width: 1.8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Birth Date
                            Text(
                              t(context, 'birthDate'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF17324D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dateText,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: _selectedBirthDate != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: _selectedBirthDate != null
                                            ? const Color(0xFF17324D)
                                            : const Color(0xFFA0B0C0),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      color: Color(0xFF00A79D),
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Gender Section
                            Text(
                              t(context, 'gender'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF17324D),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildGenderOption(
                                    label: t(context, 'male'),
                                    value: 'Laki-laki',
                                    icon: Icons.male_rounded,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildGenderOption(
                                    label: t(context, 'female'),
                                    value: 'Perempuan',
                                    icon: Icons.female_rounded,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildGenderOption(
                                    label: t(context, 'otherGender'),
                                    value: 'Lainnya',
                                    icon: Icons.transgender_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _submitProfile,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF00A79D),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
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
                                    : Text(
                                        t(context, 'continue'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderOption({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _gender == value;
    return InkWell(
      onTap: () => setState(() => _gender = value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00A79D).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00A79D)
                : Colors.white.withValues(alpha: 0.9),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF00A79D)
                  : const Color(0xFF6B8092),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF00A79D)
                    : const Color(0xFF6B8092),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
