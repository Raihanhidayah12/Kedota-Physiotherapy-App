import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/language_button.dart';
import '../errors/pin_rate_limit_screen.dart';
import '../home/home_screen.dart';
import 'forgot_pin_screen.dart';
import 'sign_in_screen.dart';

class PinVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const PinVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen> {
  String _pin = '';
  bool _isError = false;
  bool _isLoading = false;
  int _failedAttempts = 0;

  void _onNumpadTap(String value) {
    if (_isLoading) return;
    HapticFeedback.lightImpact();

    setState(() {
      _isError = false;
      if (value == 'backspace') {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_pin.length < 6) {
          _pin += value;
          if (_pin.length == 6) {
            _verifyPin();
          }
        }
      }
    });
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final service = SupabaseAuthService();
      
      // Try verifying hashed PIN against profiles table
      final isValid = await service.verifyPin(phone: widget.phoneNumber, pin: _pin);

      if (!isValid) {
        throw Exception('Invalid PIN');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'signedInSuccessfully')),
          backgroundColor: const Color(0xFF00A79D),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _isLoading = false;
        _pin = '';
        _failedAttempts++;
      });
      if (_failedAttempts >= 3) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PinRateLimitScreen(phoneNumber: widget.phoneNumber),
          ),
        );
      }
    }
  }

  Widget _buildNumpadButton(String value) {
    if (value.isEmpty) {
      return const SizedBox(width: 72, height: 72);
    }
    
    final isBackspace = value == 'backspace';
    
    return GestureDetector(
      onTap: () => _onNumpadTap(value),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(189), // 0.74 opacity
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFDCE7F5),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8CA6C8).withAlpha(25), // 0.1 opacity
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isBackspace
              ? const Icon(Icons.backspace_outlined, color: Color(0xFF17324D))
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF17324D),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 380;
    
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
          Positioned(
            top: -70,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF86D8C8).withAlpha(61), // 0.24 opacity
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -30,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8AA8FF).withAlpha(51), // 0.2 opacity
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
                          color: Colors.white.withAlpha(158), // 0.62 opacity
                          border: Border.all(
                            color: Colors.white.withAlpha(183), // 0.72 opacity
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7F9CCB).withAlpha(41), // 0.16 opacity
                              blurRadius: 24,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    } else {
                                      Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                          builder: (_) => const SignInScreen(),
                                        ),
                                        (route) => false,
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  color: const Color(0xFF17324D),
                                  tooltip: t(context, 'back'),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withAlpha(183), // 0.72 opacity
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                const SizedBox.shrink(), // Language button hidden - will be in settings
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              t(context, 'enterPin'),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF17324D),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t(context, 'enterPinDesc'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_isError) ...[
                              const SizedBox(height: 12),
                              Text(
                                t(context, 'wrongPinOrSignInFailed'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 32),
                            // 6 Dots Indicator
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(6, (index) {
                                final isActive = index < _pin.length;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isError
                                        ? Colors.red.shade400
                                        : (isActive
                                            ? const Color(0xFF00A79D)
                                            : const Color(0xFFDCE7F5)),
                                    boxShadow: isActive && !_isError
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF00A79D).withAlpha(76), // 0.3 opacity
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            )
                                          ]
                                        : null,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 48),
                            // Numpad
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildNumpadButton('1'),
                                    _buildNumpadButton('2'),
                                    _buildNumpadButton('3'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildNumpadButton('4'),
                                    _buildNumpadButton('5'),
                                    _buildNumpadButton('6'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildNumpadButton('7'),
                                    _buildNumpadButton('8'),
                                    _buildNumpadButton('9'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildNumpadButton(''),
                                    _buildNumpadButton('0'),
                                    _buildNumpadButton('backspace'),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (_isLoading)
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A79D)),
                              )
                            else
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const ForgotPinScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  t(context, 'forgotPin'),
                                  style: const TextStyle(
                                    color: Color(0xFF00A79D),
                                    fontWeight: FontWeight.w700,
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
}
