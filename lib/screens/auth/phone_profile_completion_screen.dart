import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/custom_bottom_sheet.dart';
import '../../widgets/language_button.dart';
import 'phone_create_pin_screen.dart';

class PhoneProfileCompletionScreen extends StatefulWidget {
  final String phoneNumber; // Already verified via OTP, cannot be edited

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

  DateTime? _selectedBirthDate;
  String _gender = 'Laki-laki';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }



  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
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
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: 'Error',
        subtitle: t(context, 'fullNameRequired'),
        singleButtonText: t(context, 'close') ?? 'Tutup',
        onSinglePressed: () => Navigator.of(context).pop(),
      );
      return;
    }

    if (email.isEmpty) {
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: 'Error',
        subtitle: t(context, 'emailRequired'),
        singleButtonText: t(context, 'close') ?? 'Tutup',
        onSinglePressed: () => Navigator.of(context).pop(),
      );
      return;
    }

    if (!_isValidEmail(email)) {
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: 'Error',
        subtitle: t(context, 'validEmailError'),
        singleButtonText: t(context, 'close') ?? 'Tutup',
        onSinglePressed: () => Navigator.of(context).pop(),
      );
      return;
    }

    if (_selectedBirthDate == null) {
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: 'Error',
        subtitle: t(context, 'selectBirthDateError'),
        singleButtonText: t(context, 'close') ?? 'Tutup',
        onSinglePressed: () => Navigator.of(context).pop(),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if email already exists
      final emailExists = await SupabaseAuthService().checkEmailExists(email);
      
      if (!mounted) return;
      
      if (emailExists) {
        setState(() => _isLoading = false);
        CustomBottomSheet.show(
          context,
          type: BottomSheetType.error,
          title: 'Error',
          subtitle: t(context, 'emailAlreadyRegistered'),
          singleButtonText: t(context, 'close') ?? 'Tutup',
          onSinglePressed: () => Navigator.of(context).pop(),
        );
        return;
      }

      // Navigate to PIN creation screen — replace so this screen is removed from stack
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
        title: 'Error',
        subtitle: errorMessage,
        singleButtonText: t(context, 'close') ?? 'Tutup',
        onSinglePressed: () => Navigator.of(context).pop(),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                                    color: const Color(0xFF00A79D).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF00A79D).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.verified_user_rounded,
                                        color: Color(0xFF00A79D),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        t(context, 'phoneVerified'),
                                        style: const TextStyle(
                                          color: Color(0xFF00A79D),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox.shrink(),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              t(context, 'completeYourProfile'),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF17324D),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t(context, 'phoneProfileDesc'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF6B8092),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Phone Number (Readonly, already verified)
                            Text(
                              t(context, 'phoneNumber'),
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
                                    Icons.phone_rounded,
                                    color: Color(0xFF6B8092),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      widget.phoneNumber,
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
                            // Email
                            Text(
                              t(context, 'email'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF17324D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF17324D),
                              ),
                              decoration: InputDecoration(
                                hintText: 'email@example.com',
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
