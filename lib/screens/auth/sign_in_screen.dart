import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

class _SignInScreenState extends State<SignInScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  bool _isPhoneError = false;
  static const Color _accentGreen = Color(0xFF00A79D);

  bool _isHandlingGoogleAuth = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _phoneController.addListener(() {
      if (_isPhoneError && _phoneController.text.isNotEmpty) {
        setState(() => _isPhoneError = false);
      }
    });

    // Update border saat fokus berubah (issue #1 & #9)
    _phoneFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      if (data.event == AuthChangeEvent.signedIn &&
          data.session?.user != null &&
          mounted &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        final provider = data.session?.user.appMetadata['provider'] as String?;
        if (provider == 'google' || provider == 'apple') {
          await _handleGoogleSignInResult();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignInResult() async {
    if (_isHandlingGoogleAuth) return;
    _isHandlingGoogleAuth = true;

    try {
      final service = SupabaseAuthService();
      final currentUser = service.client.auth.currentUser;

      if (currentUser == null) return;

      await service.syncProfilePhotoFromAuth();

      final googleEmail = currentUser.email ?? '';

      Map<String, dynamic>? existingProfile;
      if (googleEmail.isNotEmpty) {
        existingProfile = await service.client
            .from('profiles')
            .select(
              'id, email, signup_method, phone, pin_hash, full_name, birth_date',
            )
            .eq('email', googleEmail)
            .maybeSingle();
      }
      existingProfile ??= await service.checkUserProfileExists();

      if (!mounted) return;

      final signupMethod = (existingProfile?['signup_method'] ?? '').toString();
      final phone = (existingProfile?['phone'] ?? '').toString().trim();
      final pinHash = (existingProfile?['pin_hash'] ?? '').toString().trim();

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

      if (phone.isNotEmpty && pinHash.isNotEmpty) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PinVerificationScreen(phoneNumber: phone),
          ),
        );
        return;
      }

      if (!mounted) return;
      final metadata = currentUser.userMetadata ?? {};
      final email =
          currentUser.email ?? existingProfile?['email'] as String? ?? '';
      final fullName =
          (metadata['full_name'] ??
                  metadata['name'] ??
                  existingProfile?['full_name'] ??
                  '')
              .toString();
      final birthDateStr =
          (metadata['birth_date'] ??
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
    if (phone.isEmpty || !PhoneValidator.isValidIndonesianPhone(phone)) {
      setState(() => _isPhoneError = true);
      CustomBottomSheet.show(
        context,
        type: BottomSheetType.error,
        title: t(context, 'infoTitle'),
        subtitle: phone.isEmpty
            ? t(context, 'enterPhoneError')
            : t(context, 'validPhoneError'),
        singleButtonText: t(context, 'closeBtn'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
      return;
    }
    setState(() => _isPhoneError = false);

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
        title: t(context, 'signInFailedTitle'),
        subtitle: '${t(context, 'googleSignInFailed')}: $e',
        singleButtonText: t(context, 'closeBtn'),
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
        title: t(context, 'googleSignInFailed'),
        subtitle: '${t(context, 'appleSignInFailed')}: $e',
        singleButtonText: t(context, 'closeBtn'),
        onSinglePressed: () => Navigator.of(context).pop(),
      );
    }
  }

  Widget _buildIndonesianFlag() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        width: 20,
        height: 14,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFFCE1126), // merah Indonesia
              ),
            ),
            Expanded(
              child: Container(width: double.infinity, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // Menentukan warna border field (issue #9 — hanya 3 state: normal, error, focus)
  Color get _phoneBorderColor {
    if (_isPhoneError) return const Color(0xFFEF4444);
    if (_phoneFocusNode.hasFocus) return const Color(0xFF00A79D);
    return const Color(0xFFE2E8F0);
  }

  double get _phoneBorderWidth {
    return (_isPhoneError || _phoneFocusNode.hasFocus) ? 1.5 : 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: MediaQuery.of(context).size.height < 640 ? 16 : 28,
            ),
            child:
                Column(
                      children: [
                        Image.asset(
                          'assets/image/logo 2.png',
                          height: (MediaQuery.of(context).size.height * 0.08)
                              .clamp(48.0, 68.0),
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'K E D O T A',
                          style: TextStyle(
                            fontSize: (MediaQuery.of(context).size.width * 0.05)
                                .clamp(16.0, 22.0),
                            fontWeight: FontWeight.w900,
                            color: _accentGreen,
                            letterSpacing: 4.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'P H Y S I O T H E R A P Y',
                          style: TextStyle(
                            fontSize:
                                (MediaQuery.of(context).size.width * 0.026)
                                    .clamp(9.0, 12.0),
                            fontWeight: FontWeight.w600,
                            color: _accentGreen.withValues(alpha: 0.85),
                            letterSpacing: 4.0,
                          ),
                        ),
                      ],
                    )
                    .animate()
                    .fade(duration: 500.ms)
                    .slideY(begin: 0.2, curve: Curves.easeOutQuad),
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
                  children:
                      [
                            Center(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${t(context, 'welcome')} di ',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const TextSpan(
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
                            Center(
                              child: Text(
                                t(context, 'signInSubtitle'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            // Label nomor telepon dengan tanda *
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: t(context, 'phoneNumber'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' *',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Field telepon dengan 3 state: normal / focused / error
                            GestureDetector(
                              onTap: () => _phoneFocusNode.requestFocus(),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _phoneBorderColor,
                                    width: _phoneBorderWidth,
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
                                        focusNode: _phoneFocusNode,
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
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
                            ),
                            const SizedBox(height: 20),
                            // Button "Masuk" dengan gradient (issue #3)
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF007F78),
                                      Color(0xFF00A79D),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ElevatedButton(
                                  onPressed: _validateAndSubmitPhone,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    t(context, 'signIn'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Expanded(
                                  child: Divider(color: Color(0xFFE2E8F0)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    t(context, 'orContinueWith'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  child: Divider(color: Color(0xFFE2E8F0)),
                                ),
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
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
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
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
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
                          ]
                          .animate(interval: 50.ms)
                          .fade(duration: 400.ms)
                          .slideY(begin: 0.1, curve: Curves.easeOutQuad),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(backgroundColor: const Color(0xFFF7F9F9), body: content);
  }
}
