import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../utils/phone_validator.dart';
import '../../widgets/custom_bottom_sheet.dart';
import '../../widgets/google_logo_icon.dart';
import 'google_profile_completion_screen.dart';
import 'otp_verification_screen.dart';
import 'pin_verification_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  static const Color _accentGreen = Color(0xFF00A79D);

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  bool _isHandlingGoogleAuth = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(_entranceController);
    _scaleAnimation = Tween<double>(begin: 0.97, end: 1)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_entranceController);

    _entranceController.forward();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      if (data.event == AuthChangeEvent.signedIn &&
          data.session?.user != null) {
        final provider = data.session?.user.appMetadata['provider'] as String?;
        if ((provider == 'google' || provider == 'apple') && mounted) {
          await _handleGoogleSignInResult();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _entranceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignInResult() async {
    if (_isHandlingGoogleAuth) return;
    _isHandlingGoogleAuth = true;

    try {
      final service = SupabaseAuthService();
      final currentUser = service.client.auth.currentUser;

      if (currentUser == null) return;

      final googleEmail = currentUser.email ?? '';

      // Cari profile berdasarkan email Google atau user ID
      Map<String, dynamic>? existingProfile;
      if (googleEmail.isNotEmpty) {
        existingProfile = await service.client
            .from('profiles')
            .select('id, email, signup_method, phone, pin_hash, full_name, birth_date')
            .eq('email', googleEmail)
            .maybeSingle();
      }
      // Fallback: cari by user ID kalau tidak ketemu by email
      existingProfile ??= await service.checkUserProfileExists();

      if (!mounted) return;

      final signupMethod = (existingProfile?['signup_method'] ?? '').toString();
      final phone = (existingProfile?['phone'] ?? '').toString().trim();
      final pinHash = (existingProfile?['pin_hash'] ?? '').toString().trim();

      // Akun phone yang email-nya kebetulan sama dengan Google → verifikasi OTP dulu
      if (signupMethod == 'phone' && phone.isNotEmpty) {
        await service.signOut();
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: phone,
              onVerified: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => PinVerificationScreen(phoneNumber: phone),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
        );
        return;
      }

      // Akun Google sudah lengkap (ada phone + pin_hash) → langsung masuk PIN
      if (phone.isNotEmpty && pinHash.isNotEmpty) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PinVerificationScreen(phoneNumber: phone),
          ),
        );
        return;
      }

      // Akun Google belum lengkap (phone atau pin kosong) → ke profile completion
      if (!mounted) return;
      final metadata = currentUser.userMetadata ?? {};
      final email = currentUser.email ?? existingProfile?['email'] as String? ?? '';
      final fullName = (metadata['full_name'] ??
              metadata['name'] ??
              existingProfile?['full_name'] ??
              '')
          .toString();
      // Jangan ambil phone dari metadata Google — user harus isi manual
      final birthDateStr = (metadata['birth_date'] ??
              metadata['birthday'] ??
              existingProfile?['birth_date'] ??
              '')
          .toString();

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GoogleProfileCompletionScreen(
            email: email,
            initialFullName: fullName,
            initialPhone: '',
            initialBirthDateStr: birthDateStr,
          ),
        ),
      );
    } finally {
      _isHandlingGoogleAuth = false;
    }
  }

  void _validateAndSubmitPhone() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: 'Informasi',
        subtitle: t(context, 'enterPhoneError'),
        singleButtonText: t(context, 'close'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
      return;
    }

    if (!PhoneValidator.isValidIndonesianPhone(phone)) {
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: 'Informasi',
        subtitle: t(context, 'validPhoneError'),
        singleButtonText: t(context, 'close'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phoneNumber: PhoneValidator.normalizePhoneNumber(phone),
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    try {
      final service = SupabaseAuthService();
      await service.signInWithGoogle(
        redirectTo: kIsWeb ? null : 'io.supabase.flutter://login-callback',
      );
    } catch (e) {
      if (!mounted) return;
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: 'Gagal Masuk',
        subtitle: '${t(context, 'googleSignInFailed')}: $e',
        singleButtonText: t(context, 'close'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
    }
  }

  Future<void> _signInWithApple() async {
    try {
      final service = SupabaseAuthService();
      await service.signInWithApple(
        redirectTo: kIsWeb ? null : 'io.supabase.flutter://login-callback',
      );
    } catch (e) {
      if (!mounted) return;
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: 'Gagal Masuk',
        subtitle: 'Apple Sign-In Gagal: $e',
        singleButtonText: t(context, 'close'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
    }
  }

  Widget _buildIndonesianFlag() {
    return Container(
      width: 20,
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
      ),
      child: Column(
        children: [
          Expanded(child: Container(color: const Color(0xFFE53E3E))),
          Expanded(child: Container(color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Image.asset(
                  'assets/image/logo 2.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                const Text(
                  'K E D O T A',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _accentGreen,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'P H Y S I O T H E R A P Y',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _accentGreen.withValues(alpha: 0.85),
                    letterSpacing: 4.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text.rich(
                        TextSpan(
                          children: const [
                            TextSpan(
                              text: 'Selamat Datang di ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            TextSpan(
                              text: 'Kedota!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: _accentGreen,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Silakan masuk ke akun Anda atau daftar sekarang untuk memulai perjalanan bersama kami.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Masukkan No. Telp',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          _buildIndonesianFlag(),
                          const SizedBox(width: 8),
                          const Text(
                            '+62',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 1,
                            height: 20,
                            color: const Color(0xFFE2E8F0),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(13),
                              ],
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: '08XX XXXX XXXX',
                                hintStyle: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _validateAndSubmitPhone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Masuk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: const [
                        Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Atau Masuk dengan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            GoogleLogoIcon(size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Google',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _signInWithApple,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.apple,
                              color: Color(0xFF1E293B),
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Apple',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFE8F6F4),
      body: AnimatedBuilder(
        animation: _entranceController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(scale: _scaleAnimation, child: child),
            ),
          );
        },
        child: content,
      ),
    );
  }
}
