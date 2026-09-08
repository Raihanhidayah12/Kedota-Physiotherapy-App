import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../services/screen_security_service.dart';
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

class _PhoneCreatePinScreenState extends State<PhoneCreatePinScreen>
    with SecureScreenMixin {
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

  Widget _buildNumpadButton(String value, double btnSize) {
    if (value.isEmpty) {
      return SizedBox(width: btnSize, height: btnSize);
    }

    final isBackspace = value == 'backspace';

    return GestureDetector(
      onTap: () => _onNumberPressed(value),
      child: Container(
        width: btnSize,
        height: isBackspace ? btnSize * 0.76 : btnSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: isBackspace ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isBackspace ? BorderRadius.circular(14) : null,
          border: isBackspace ? Border.all(color: const Color(0xFF00A79D), width: 2) : null,
          boxShadow: isBackspace
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: isBackspace
              ? Icon(Icons.backspace_outlined, color: const Color(0xFF00A79D), size: btnSize * 0.33)
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: btnSize * 0.36,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _firstPin;
    final minH = MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH > 0 ? minH : 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
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
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isPinError
                                ? (isFilled ? const Color(0xFFEF4444) : Colors.transparent)
                                : (isFilled ? const Color(0xFF00A79D) : Colors.transparent),
                            border: Border.all(
                              color: _isPinError
                                  ? const Color(0xFFEF4444)
                                  : isFilled
                                      ? const Color(0xFF00A79D)
                                      : const Color(0xFFCBD5E1),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // NUMERIC KEYPAD
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = MediaQuery.sizeOf(context).width;
                    const bs = 100.0;
                    const hGap = 16.0;
                    const vGap = 16.0;
                    final totalW = bs * 3 + hGap * 2;
                    final hPad = (w - totalW) / 2;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: SizedBox(
                        width: totalW,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: ['1','2','3'].map((v) => _buildNumpadButton(v, bs)).toList(),
                            ),
                            const SizedBox(height: vGap),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: ['4','5','6'].map((v) => _buildNumpadButton(v, bs)).toList(),
                            ),
                            const SizedBox(height: vGap),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: ['7','8','9'].map((v) => _buildNumpadButton(v, bs)).toList(),
                            ),
                            const SizedBox(height: vGap),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: ['','0','backspace'].map((v) => _buildNumpadButton(v, bs)).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
