import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_language.dart';
import '../../services/app_lock_service.dart';
import '../../services/screen_security_service.dart';
import '../../services/supabase_auth_service.dart';
import '../errors/pin_rate_limit_screen.dart';
import '../home/main_screen.dart';
import 'forgot_pin_screen.dart';

class PinVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const PinVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen>
    with SecureScreenMixin {
  String _pin = '';
  bool _isError = false;
  bool _isLoading = false;
  int _failedAttempts = 0;
  bool _showBiometricBtn = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // Cek biometric dan langsung trigger saat screen muncul
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBiometric();
    });
  }

  /// Cek apakah biometric aktif untuk user ini, lalu langsung trigger prompt
  Future<void> _initBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final isBioForThisUser =
        prefs.getBool('biometric_pin_enabled_${widget.phoneNumber}') ?? false;

    if (!isBioForThisUser || !mounted) return;

    // Tampilkan icon fingerprint di numpad
    setState(() => _showBiometricBtn = true);

    // Langsung trigger biometric tanpa perlu user tekan tombol
    await _verifyBiometric();
  }

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
    setState(() => _isLoading = true);

    try {
      final service = SupabaseAuthService();
      final isValid = await service.verifyPin(
        phone: widget.phoneNumber,
        pin: _pin,
      );

      if (!isValid) throw Exception('Invalid PIN');
      if (!mounted) return;

      // Bind phone number setelah login berhasil
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', widget.phoneNumber);
      await AppLockService.setUserPhone(widget.phoneNumber);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
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

  Future<void> _verifyBiometric() async {
    if (_isLoading || _isAuthenticating || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('biometric_pin_enabled_${widget.phoneNumber}') ??
        false)) {
      return;
    }

    _isAuthenticating = true;
    setState(() => _isLoading = true);

    try {
      final authenticated = await LocalAuthentication().authenticate(
        localizedReason: t(context, 'biometricReason'),
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!authenticated || !mounted) {
        // User cancel → biarkan masuk PIN manual
        setState(() => _isLoading = false);
        return;
      }

      // Biometric berhasil — cek/refresh Supabase session
      final supabase = SupabaseAuthService();
      final currentSession = supabase.client.auth.currentSession;

      if (currentSession != null) {
        await AppLockService.setUserPhone(widget.phoneNumber);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      } else {
        try {
          await supabase.client.auth.refreshSession();
          await AppLockService.setUserPhone(widget.phoneNumber);
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
          );
        } catch (_) {
          // Session expired — minta PIN
          if (mounted) {
            setState(() {
              _isError = true;
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t(context, 'sessionExpiredUsePIN')),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        }
      }
    } on PlatformException {
      // Biometric error — biarkan user pakai PIN
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isAuthenticating = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildNumpadButton(String value, double btnSize) {
    if (value.isEmpty) {
      return SizedBox(width: btnSize, height: btnSize);
    }

    if (value == 'backspace') {
      return GestureDetector(
        onTap: () => _onNumpadTap(value),
        child: SizedBox(
          width: btnSize,
          height: btnSize,
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              color: const Color(0xFF00A79D),
              size: btnSize * 0.42,
            ),
          ),
        ),
      );
    }

    if (value == 'biometric') {
      return GestureDetector(
        onTap: _verifyBiometric,
        child: SizedBox(
          width: btnSize,
          height: btnSize,
          child: Center(
            child: Icon(
              Icons.fingerprint_rounded,
              color: const Color(0xFF00A79D),
              size: btnSize * 0.52,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onNumpadTap(value),
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
              fontSize: btnSize * 0.35,
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
    final screenSize = MediaQuery.sizeOf(context);
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;

    final iconSize = (screenHeight * 0.075).clamp(42.0, 64.0);
    final fontSubtitle = (screenWidth * 0.034).clamp(11.0, 16.0);
    final pinDotSize = (screenWidth * 0.04).clamp(14.0, 22.0);
    final pinDotMargin = (screenWidth * 0.013).clamp(4.0, 7.0);
    const numpadBtnSize = 100.0;
    const numpadHGap = 16.0;
    const numpadVGap = 16.0;
    final numpadTotalWidth = numpadBtnSize * 3 + numpadHGap * 2;
    final numpadHPad = (screenWidth - numpadTotalWidth) / 2;

    final sp1 = (screenHeight * 0.018).clamp(8.0, 14.0);
    final sp2 = (screenHeight * 0.024).clamp(12.0, 18.0);
    final sp4 = (screenHeight * 0.025).clamp(18.0, 28.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      body: SafeArea(
        child: Column(
          children: [
            // ── Atas: icon + subtitle + dots ────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Lock icon ─────────────────────────────────────────
                  Icon(
                    Icons.lock_person_outlined,
                    size: iconSize,
                    color: const Color(0xFF00A79D),
                  ),
                  SizedBox(height: sp1),

                  // ── Subtitle ──────────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.1,
                    ),
                    child: Text(
                      t(context, 'enterPinDesc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSubtitle,
                        color: const Color(0xFF334155),
                        height: 1.45,
                      ),
                    ),
                  ),
                  SizedBox(height: sp2),

                  // ── Error message ─────────────────────────────────────
                  if (_isError)
                    Padding(
                      padding: EdgeInsets.only(bottom: screenHeight * 0.012),
                      child: Text(
                        t(context, 'wrongPinOrSignInFailed'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),

                  // ── 6 PIN dots ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final isFilled = index < _pin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isError
                              ? (isFilled
                                    ? const Color(0xFFEF4444)
                                    : Colors.transparent)
                              : (isFilled
                                    ? const Color(0xFF00A79D)
                                    : Colors.transparent),
                          border: Border.all(
                            color: _isError
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
            ),

            // ── Bawah: numpad + lupa PIN ─────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: numpadHPad),
              child: SizedBox(
                width: numpadTotalWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNumpadButton('1', numpadBtnSize),
                        _buildNumpadButton('2', numpadBtnSize),
                        _buildNumpadButton('3', numpadBtnSize),
                      ],
                    ),
                    SizedBox(height: numpadVGap),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNumpadButton('4', numpadBtnSize),
                        _buildNumpadButton('5', numpadBtnSize),
                        _buildNumpadButton('6', numpadBtnSize),
                      ],
                    ),
                    SizedBox(height: numpadVGap),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNumpadButton('7', numpadBtnSize),
                        _buildNumpadButton('8', numpadBtnSize),
                        _buildNumpadButton('9', numpadBtnSize),
                      ],
                    ),
                    SizedBox(height: numpadVGap),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _showBiometricBtn
                            ? _buildNumpadButton('biometric', numpadBtnSize)
                            : SizedBox(
                                width: numpadBtnSize,
                                height: numpadBtnSize,
                              ),
                        _buildNumpadButton('0', numpadBtnSize),
                        _buildNumpadButton('backspace', numpadBtnSize),
                      ],
                    ),
                    SizedBox(height: sp4),

                    // ── Lupa PIN link ─────────────────────────────────────
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ForgotPinOtpScreen(
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
                      child: Text(
                        t(context, 'forgotPin'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF00A79D),
                        ),
                      ),
                    ),
                    SizedBox(height: sp1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
