import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/custom_bottom_sheet.dart';
import '../home/home_screen.dart';

class GoogleCreatePinScreen extends StatefulWidget {
  final String phone;
  final String fullName;
  final String email;
  final DateTime birthDate;
  final String gender;

  const GoogleCreatePinScreen({
    super.key,
    required this.phone,
    required this.fullName,
    required this.email,
    required this.birthDate,
    required this.gender,
  });

  @override
  State<GoogleCreatePinScreen> createState() => _GoogleCreatePinScreenState();
}

class _GoogleCreatePinScreenState extends State<GoogleCreatePinScreen> {
  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;

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
                isError ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded,
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

  void _onNumberPressed(String val) {
    HapticFeedback.selectionClick();

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
      _showModernSnackBar(t(context, 'confirmPinMismatchError'), isError: true);
      setState(() {
        _firstPin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseAuthService().completeSocialProfile(
        provider: 'google',
        phone: widget.phone,
        fullName: widget.fullName,
        birthDate: widget.birthDate,
        gender: widget.gender,
        pin: _firstPin,
        email: widget.email,
      );

      if (!mounted) return;

      CustomBottomSheet.show(
        context,
        type: BottomSheetType.success,
        title: t(context, 'profileCompletedTitle'),
        subtitle: t(context, 'profileCompletedSubtitle'),
        singleButtonText: t(context, 'continueText'),
        isDismissible: false,
        onSinglePressed: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Google profile completion error: $e');
      _showModernSnackBar(t(context, 'saveProfileFailed'), isError: true);
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

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _firstPin;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 20 : 28,
                vertical: 24,
              ),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_isConfirming) {
                                  setState(() {
                                    _isConfirming = false;
                                    _confirmPin = '';
                                  });
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: const Color(0xFF17324D),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.72),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox.shrink(), // Language button hidden
                    ],
                  ),
                  const Spacer(),

                  // Title & Description
                  Text(
                    _isConfirming
                        ? t(context, 'confirmPin')
                        : t(context, 'createPin'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17324D),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(context, 'createPinDesc'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // PIN Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final isFilled = index < currentPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? const Color(0xFF00A79D)
                              : Colors.transparent,
                          border: Border.all(
                            color: isFilled
                                ? const Color(0xFF00A79D)
                                : const Color(0xFFCBD5E1),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),

                  // Number Pad
                  if (_isLoading)
                    const CircularProgressIndicator(
                      color: Color(0xFF00A79D),
                    )
                  else
                    _buildNumberPad(isCompact),

                  SizedBox(height: isCompact ? 16 : 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad(bool isCompact) {
    final buttonSize = isCompact ? 72.0 : 80.0;
    final fontSize = isCompact ? 26.0 : 28.0;

    return Column(
      children: [
        for (int row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int col = 1; col <= 3; col++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildNumberButton(
                      '${row * 3 + col}',
                      buttonSize,
                      fontSize,
                    ),
                  ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: buttonSize + 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildNumberButton('0', buttonSize, fontSize),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildBackspaceButton(buttonSize),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number, double size, double fontSize) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onNumberPressed(number),
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF1F5F9),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF17324D),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(double size) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onBackspace,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFEF2F2),
            border: Border.all(
              color: const Color(0xFFFECACA),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.backspace_outlined,
            color: Color(0xFFDC2626),
            size: 24,
          ),
        ),
      ),
    );
  }
}
