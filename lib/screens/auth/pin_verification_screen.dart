import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_auth_service.dart';
import '../errors/pin_rate_limit_screen.dart';
import '../home/home_screen.dart';
import 'forgot_pin_screen.dart';
import 'otp_verification_screen.dart';

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
      final isValid = await service.verifyPin(
        phone: widget.phoneNumber,
        pin: _pin,
      );

      if (!isValid) {
        throw Exception('Invalid PIN');
      }

      if (!mounted) return;

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

    if (isBackspace) {
      return GestureDetector(
        onTap: () => _onNumpadTap(value),
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
      onTap: () => _onNumpadTap(value),
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 36),

            // TOP LOCK BADGE ICON
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Masukkan 6 digit PIN Anda untuk masuk.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF334155),
                  height: 1.45,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ERROR MESSAGE (WHEN PIN IS WRONG)
            if (_isError)
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
                final isFilled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isError
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

            // LUPA PIN LINK
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OtpVerificationScreen(
                      phoneNumber: widget.phoneNumber,
                      onVerified: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => BirthDateVerificationScreen(
                              phoneNumber: widget.phoneNumber,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              child: const Text(
                'Lupa PIN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00A79D),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
