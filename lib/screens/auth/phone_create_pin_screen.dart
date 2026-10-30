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
        singleButtonText: t(context, 'close'),
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

    if (isBackspace) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onNumberPressed(value),
        child: SizedBox(
          width: btnSize,
          height: btnSize,
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              color: const Color(0xFF00A79D),
              size: btnSize * 0.40,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onNumberPressed(value),
      child: Container(
        width: btnSize,
        height: btnSize,
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

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isConfirming) {
          setState(() {
            _isConfirming = false;
            _confirmPin = '';
            _firstPin = '';
          });
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9F9),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final dotSize = (w * 0.065).clamp(18.0, 26.0);
              final dotMargin = (w * 0.02).clamp(4.0, 8.0);

              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: h),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            SizedBox(height: (h * 0.035).clamp(16.0, 36.0)),

                            // LOCK ICON BADGE
                            Center(
                              child: Container(
                                width: (h * 0.08).clamp(52.0, 64.0),
                                height: (h * 0.08).clamp(52.0, 64.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F6F4),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.lock_person_outlined,
                                  size: (h * 0.045).clamp(28.0, 36.0),
                                  color: const Color(0xFF00A79D),
                                ),
                              ),
                            ),
                            SizedBox(height: (h * 0.02).clamp(12.0, 18.0)),

                            // SUBTITLE TEXT
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 28),
                              child: Text(
                                _isConfirming
                                    ? 'Silakan masukkan kembali 6 digit PIN Anda untuk konfirmasi.'
                                    : 'Silakan buat 6 digit PIN Anda terlebih dahulu untuk melanjutkan.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF334155),
                                  height: 1.45,
                                ),
                              ),
                            ),

                            SizedBox(height: (h * 0.025).clamp(14.0, 24.0)),

                            // ERROR TEKS (PIN MISMATCH)
                            if (_isPinError)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'PIN tidak sesuai silakan coba lagi.',
                                  style: TextStyle(
                                    fontSize: 13,
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
                                  margin: EdgeInsets.symmetric(horizontal: dotMargin),
                                  width: dotSize,
                                  height: dotSize,
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

                        // NUMERIC KEYPAD
                        Builder(
                          builder: (context) {
                            final hGap = (w * 0.045).clamp(10.0, 18.0);
                            final vGap = (h * 0.016).clamp(8.0, 16.0);
                            final maxByWidth = (w - 48 - (hGap * 2)) / 3;
                            final maxByHeight = h * 0.092;
                            final bs = maxByWidth.clamp(50.0, 78.0).clamp(50.0, maxByHeight);
                            final totalW = bs * 3 + hGap * 2;
                            final hPad = ((w - totalW) / 2).clamp(0.0, w / 2);

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
                                    SizedBox(height: vGap),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: ['4','5','6'].map((v) => _buildNumpadButton(v, bs)).toList(),
                                    ),
                                    SizedBox(height: vGap),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: ['7','8','9'].map((v) => _buildNumpadButton(v, bs)).toList(),
                                    ),
                                    SizedBox(height: vGap),
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

                        SizedBox(height: (h * 0.03).clamp(16.0, 36.0)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
