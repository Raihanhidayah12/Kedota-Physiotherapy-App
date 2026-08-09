import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/custom_bottom_sheet.dart';
import 'account_created_screen.dart';

class PhoneCreatePinScreen extends StatefulWidget {
  final String phone;
  final String fullName;
  final String email;
  final DateTime birthDate;
  final String gender;

  const PhoneCreatePinScreen({
    super.key,
    required this.phone,
    required this.fullName,
    required this.email,
    required this.birthDate,
    required this.gender,
  });

  @override
  State<PhoneCreatePinScreen> createState() => _PhoneCreatePinScreenState();
}

class _PhoneCreatePinScreenState extends State<PhoneCreatePinScreen> {
  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;
  bool _isPinError = false;

  void _showPinError() {
    setState(() => _isPinError = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isPinError = false);
    });
  }

  void _onNumberPressed(String val) {
    if (_isLoading) return;
    HapticFeedback.selectionClick();

    if (val == 'backspace') {
      _onBackspace();
      return;
    }

    if (!_isConfirming) {
      if (_firstPin.length < 6) {
        setState(() => _firstPin += val);
        if (_firstPin.length == 6) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() => _isConfirming = true);
            }
          });
        }
      }
    } else {
      if (_confirmPin.length < 6) {
        setState(() => _confirmPin += val);
        if (_confirmPin.length == 6) {
          _handlePinSubmission();
        }
      }
    }
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();

    if (!_isConfirming) {
      if (_firstPin.isNotEmpty) {
        setState(() {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        });
      }
    } else {
      if (_confirmPin.isNotEmpty) {
        setState(() {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        });
      } else {
        setState(() {
          _isConfirming = false;
          _firstPin = '';
        });
      }
    }
  }

  Future<void> _handlePinSubmission() async {
    if (_firstPin != _confirmPin) {
      setState(() {
        _confirmPin = '';
        _isConfirming = true;
      });
      _showPinError();
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseAuthService().createPhoneProfile(
        phone: widget.phone,
        fullName: widget.fullName,
        email: widget.email,
        birthDate: widget.birthDate,
        gender: widget.gender,
        pin: _firstPin,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AccountCreatedScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Phone profile creation error: $e');

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

      setState(() {
        _firstPin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildNumpadButton(String value) {
    if (value.isEmpty) {
      return const SizedBox(width: 68, height: 68);
    }

    final isBackspace = value == 'backspace';

    if (isBackspace) {
      return GestureDetector(
        onTap: () => _onNumberPressed(value),
        child: Container(
          width: 68,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00A79D), width: 2),
          ),
          child: const Center(
            child: Icon(
              Icons.backspace_outlined,
              color: Color(0xFF00A79D),
              size: 24,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onNumberPressed(value),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _firstPin;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 36),

            // LOCK ICON BADGE
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  size: 36,
                  color: Color(0xFF00A79D),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SUBTITLE TEXT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _isConfirming
                    ? 'Silakan masukkan kembali 6 digit PIN Anda untuk konfirmasi.'
                    : 'Silakan buat 6 digit PIN Anda terlebih dahulu untuk melanjutkan.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF334155),
                  height: 1.45,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ERROR TEKS (PIN MISMATCH)
            if (_isPinError)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'PIN tidak sesuai silakan coba lagi.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),

            // 6 PIN DOTS INDICATOR
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < currentPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPinError
                        ? (isFilled
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFE2E8F0))
                        : (isFilled
                              ? const Color(0xFF00A79D)
                              : const Color(0xFFE2E8F0)),
                  ),
                );
              }),
            ),

            const Spacer(),

            // NUMERIC KEYPAD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildNumpadButton('1')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('2')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('3')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildNumpadButton('4')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('5')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('6')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildNumpadButton('7')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('8')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('9')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildNumpadButton('')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('0')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumpadButton('backspace')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}
