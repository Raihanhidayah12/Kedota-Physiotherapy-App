import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../l10n/app_language.dart';
import '../services/app_lock_service.dart';
import '../services/screen_security_service.dart';
import '../services/supabase_auth_service.dart';

/// Global navigator key — dipakai AppLockObserver untuk push lock screen
/// ke atas route stack manapun, seperti cara WhatsApp.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Notifier untuk memberitahu AppLockWrapper saat phone number berubah (post-login).
final appLockPhoneNotifier = ValueNotifier<String>('');

/// Observer yang dipasang ke [WidgetsBinding].
/// Saat app paused → tandai locked.
/// Saat app resumed → push AppLockScreen jika locked.
class AppLockObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // App keluar ke background → tandai locked
      // 'paused' = normal background, 'hidden' = dikurangi visibility
      AppLockService.lock();
    } else if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    final locked = await AppLockService.isLocked();
    if (!locked) return;

    // Ambil phone number terbaru
    final phone = await AppLockService.getBoundPhone() ?? '';

    // Kalau phone kosong, tidak ada yang perlu di-lock
    // (user belum login, tidak perlu lock screen)
    if (phone.isEmpty) {
      await AppLockService.unlock();
      return;
    }

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    // Cek apakah AppLockScreen sudah ada di stack (hindari push ganda)
    var alreadyShowing = false;
    nav.popUntil((route) {
      if (route.settings.name == AppLockScreen.routeName) {
        alreadyShowing = true;
      }
      return true; // jangan pop apapun
    });
    if (alreadyShowing) return;

    // Push lock screen — tidak ada back button, user HARUS autentikasi
    nav.push(
      PageRouteBuilder(
        settings: const RouteSettings(name: AppLockScreen.routeName),
        opaque: true,
        pageBuilder: (_, _, _) => AppLockScreen(phoneNumber: phone),
        transitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

/// Widget wrapper yang memasang AppLockObserver ke WidgetsBinding.
/// Letakkan ini di atas MaterialApp sebagai [home].
class AppLockWrapper extends StatefulWidget {
  final Widget child;

  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> {
  final _observer = AppLockObserver();

  @override
  void initState() {
    super.initState();
    // JANGAN unlock saat init — biarkan state lock yang ada tetap ada
    // Hanya pasang observer agar lifecycle terpantau
    WidgetsBinding.instance.addObserver(_observer);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_observer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Lock screen yang di-push ke atas navigator saat app resume dalam kondisi locked.
/// Identik dengan WA — halaman penuh, tidak ada back.
class AppLockScreen extends StatefulWidget {
  static const routeName = '/app-lock';
  final String phoneNumber;

  const AppLockScreen({super.key, required this.phoneNumber});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SecureScreenMixin {
  String _pin = '';
  bool _isError = false;
  bool _isLoading = false;
  bool _showBiometric = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricAvailability();
  }

  Future<void> _loadBiometricAvailability() async {
    if (kIsWeb) return;
    final available = await AppLockService.isBiometricEnabled(
      widget.phoneNumber,
    );
    if (mounted) {
      setState(() => _showBiometric = available);
      if (available) _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    if (kIsWeb || _isAuthenticating || !mounted) return;
    _isAuthenticating = true;

    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      if (!canCheck || !mounted) return;

      final authenticated = await auth.authenticate(
        localizedReason: t(context, 'biometricReason'),
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated && mounted) {
        await AppLockService.unlock();
        Navigator.of(context).pop();
      }
    } on PlatformException {
      // biometric gagal — biarkan user pakai PIN
    } finally {
      _isAuthenticating = false;
    }
  }

  void _onNumpadTap(String value) {
    if (_isLoading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isError = false;
      if (value == 'backspace') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else {
        if (_pin.length < 6) {
          _pin += value;
          if (_pin.length == 6) _submitPin();
        }
      }
    });
  }

  Future<void> _submitPin() async {
    setState(() => _isLoading = true);
    try {
      final isValid = await SupabaseAuthService().verifyPin(
        phone: widget.phoneNumber,
        pin: _pin,
      );
      if (!isValid) throw Exception('wrong');
      if (!mounted) return;
      await AppLockService.unlock();
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isError = true;
          _isLoading = false;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final h = size.height;

    final iconSize = (w * 0.18).clamp(56.0, 80.0);
    final dotSize = (w * 0.034).clamp(10.0, 16.0);
    final titleSize = (w * 0.055).clamp(17.0, 22.0);
    final subtitleSize = (w * 0.035).clamp(11.0, 14.0);
    final sp2 = (h * 0.025).clamp(14.0, 28.0);

    // Formula baru: fixed btn 72px, hGap 16px, vGap 16px
    const btnSize = 100.0;
    const hGap = 16.0;
    const vGap = 16.0;
    final totalW = btnSize * 3 + hGap * 2;
    final hPad = (w - totalW) / 2;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9F9),
        body: SafeArea(
          child: Column(
            children: [
              // ── Atas: icon + title + dots ──────────────────────────────
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF007F78), Color(0xFF00A79D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00A79D).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(Icons.lock_rounded, color: Colors.white, size: iconSize * 0.48),
                    ),
                    SizedBox(height: sp2),
                    Text(
                      t(context, 'appLockedTitle'),
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        t(context, 'appLockedDesc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: subtitleSize,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ),
                    SizedBox(height: sp2),

                    // PIN dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (i) {
                        final filled = i < _pin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isError
                                ? (filled ? const Color(0xFFEF4444) : Colors.transparent)
                                : (filled ? const Color(0xFF00A79D) : Colors.transparent),
                            border: Border.all(
                              color: _isError
                                  ? const Color(0xFFEF4444)
                                  : filled
                                      ? const Color(0xFF00A79D)
                                      : const Color(0xFFCBD5E1),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    if (_isError) ...[
                      const SizedBox(height: 8),
                      Text(
                        t(context, 'wrongPinError'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Bawah: numpad ──────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: SizedBox(
                  width: totalW,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['1','2','3'].map((d) => _numpadBtn(d, btnSize)).toList(),
                      ),
                      SizedBox(height: vGap),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['4','5','6'].map((d) => _numpadBtn(d, btnSize)).toList(),
                      ),
                      SizedBox(height: vGap),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['7','8','9'].map((d) => _numpadBtn(d, btnSize)).toList(),
                      ),
                      SizedBox(height: vGap),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _showBiometric
                              ? _iconBtn(Icons.fingerprint_rounded, _tryBiometric, btnSize)
                              : SizedBox(width: btnSize, height: btnSize),
                          _numpadBtn('0', btnSize),
                          _iconBtn(Icons.backspace_outlined,
                              () => _onNumpadTap('backspace'), btnSize,
                              iconColor: const Color(0xFF64748B)),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numpadBtn(String digit, double size) => SizedBox(
    width: size, height: size,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _onNumpadTap(digit),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _iconBtn(IconData icon, VoidCallback onTap, double size,
      {Color iconColor = const Color(0xFF00A79D)}) =>
      SizedBox(
    width: size, height: size,
    child: Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(
          child: Icon(icon, size: size * 0.44, color: iconColor),
        ),
      ),
    ),
  );
}
