import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/google_logo_icon.dart';
import '../../widgets/language_button.dart';
import '../../widgets/custom_bottom_sheet.dart';
import '../home/home_screen.dart';
import 'forgot_pin_screen.dart';
import 'google_profile_completion_screen.dart';
import 'otp_verification_screen.dart';
import 'pin_verification_screen.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  static const Color _accentGreen = Color(0xFF00A79D);
  bool _isLoading = false;
  bool _isHandlingGoogleAuth = false;
  StreamSubscription<AuthState>? _authSubscription;
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  Future<void> _handleGoogleSignInResult() async {
    if (_isHandlingGoogleAuth) return;
    _isHandlingGoogleAuth = true;

    try {
      final service = SupabaseAuthService();
      final currentUser = service.client.auth.currentUser;
      
      if (currentUser == null) return;
      
      final googleEmail = currentUser.email ?? '';
      
      // Check if this Google email is already registered via phone signup
      if (googleEmail.isNotEmpty) {
        final existingProfile = await service.client
            .from('profiles')
            .select('id, email, auth_email, signup_method, phone, pin_hash')
            .eq('email', googleEmail)
            .maybeSingle();
        
        if (!mounted) return;
        
        // Email exists and was registered via phone →
        // sign out the Google session, then send user through OTP on that phone number.
        // After OTP passes, go straight to PinVerificationScreen (not profile completion).
        if (existingProfile != null &&
            existingProfile['signup_method'] == 'phone') {
          
          final phone = (existingProfile['phone'] ?? '').toString();

          // Sign out the Google-only session — we'll authenticate as the phone user.
          await service.signOut();

          if (!mounted) return;

          // Go to OTP screen; on success jump straight to PIN (skip profile completion).
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                phoneNumber: phone,
                // onVerified fires after OTP is accepted — go directly to PIN.
                onVerified: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => PinVerificationScreen(phoneNumber: phone),
                    ),
                    (route) => route.isFirst, // keep SignInScreen at bottom
                  );
                },
              ),
            ),
          );
          return;
        }
      }
      
      // Continue with normal Google OAuth flow
      final profileExists = await service.checkUserProfileExists();
      if (!mounted) return;

      final phone = (profileExists?['phone'] ?? '').toString().trim();
      final pinHash = (profileExists?['pin_hash'] ?? '').toString().trim();
      final isCompleteFlag = profileExists?['is_profile_complete'] == true;

      // Profile is ONLY complete if phone is NOT empty AND (is_profile_complete is true OR pin_hash is present)
      final isProfileComplete = phone.isNotEmpty && (isCompleteFlag || pinHash.isNotEmpty);

      if (!isProfileComplete) {
        final metadata = currentUser.userMetadata ?? {};
        final email = currentUser.email ?? profileExists?['email'] as String? ?? '';
        final fullName = metadata['full_name'] ?? metadata['name'] ?? profileExists?['full_name'] ?? '';
        final initialPhone = (metadata['phone_number'] ?? metadata['phone'] ?? phone).toString().trim();
        final birthDateStr = metadata['birth_date'] ?? metadata['birthday'] ?? profileExists?['birth_date'] ?? '';

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GoogleProfileCompletionScreen(
              email: email,
              initialFullName: fullName.toString(),
              initialPhone: initialPhone,
              initialBirthDateStr: birthDateStr.toString(),
            ),
          ),
        );
      } else {
        _showModernSnackBar(t(context, 'googleVerifiedEnterPin'));
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PinVerificationScreen(
              phoneNumber: phone,
            ),
          ),
        );
      }
    } finally {
      _isHandlingGoogleAuth = false;
    }
  }

  bool _isValidIndonesianPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;

    // Format: 628xxxxxxxxx (11-13 digits after 62)
    if (digits.startsWith('628')) {
      return digits.length >= 12 && digits.length <= 14;
    }

    // Format: 08xxxxxxxxx (10-12 digits)
    if (digits.startsWith('08')) {
      return digits.length >= 11 && digits.length <= 13;
    }

    // Format: 8xxxxxxxxx (9-11 digits without 0 or country code)
    if (digits.startsWith('8')) {
      return digits.length >= 10 && digits.length <= 12;
    }

    return false;
  }

  String _normalizePhoneNumber(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('62')) {
      return '+$digits';
    }

    if (digits.startsWith('0')) {
      return '+62${digits.substring(1)}';
    }

    if (digits.startsWith('8')) {
      return '+62$digits';
    }

    return '+62$digits';
  }

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _entranceController.forward();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn && data.session?.user != null) {
        // Only handle Google OAuth sign-in, not phone signup or other methods
        final provider = data.session?.user.appMetadata['provider'] as String?;
        if (provider == 'google' && mounted) {
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
                color: _accentGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: _accentGreen,
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

  void _showUnregisteredDialog({bool isGoogle = false}) {
    CustomBottomSheet.show(
      context,
      type: BottomSheetType.error,
      title: isGoogle
          ? t(context, 'googleAccountNotRegistered')
          : t(context, 'unregisteredDialogContent').split('. ')[0],
      subtitle: isGoogle
          ? t(context, 'googleUnregisteredDialogContent')
          : t(context, 'pleaseSignUpFirst'),
      primaryButtonText: t(context, 'signUp'),
      onPrimaryPressed: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SignUpScreen()),
        );
      },
      secondaryButtonText: t(context, 'cancel'),
      onSecondaryPressed: () => Navigator.of(context).pop(),
    );
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}*@$domain';
    }
    return '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}@$domain';
  }

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return phone;
    return '${digits.substring(0, 4)}${'*' * (digits.length - 7)}${digits.substring(digits.length - 3)}';
  }

  void _showDormantAccountDialog({
    required String phoneNumber,
    required String email,
  }) {
    final maskedEmail = _maskEmail(email);
    CustomBottomSheet.show(
      context,
      type: BottomSheetType.error,
      title: t(context, 'dormantAccountTitle'),
      subtitle: '${t(context, 'dormantAccountSubtitle')}\n\nEmail: $maskedEmail',
      primaryButtonText: t(context, 'continueEmail'),
      onPrimaryPressed: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: phoneNumber,
              isDormant: true,
              targetEmail: email,
            ),
          ),
        );
      },
      secondaryButtonText: t(context, 'cancel'),
      onSecondaryPressed: () => Navigator.of(context).pop(),
    );
  }

  Future<void> _signInWithGoogle() async {
    try {
      final service = SupabaseAuthService();
      await service.signInWithGoogle(
        redirectTo: kIsWeb ? null : 'io.supabase.flutter://login-callback',
      );

      if (!mounted) return;

      final currentUser = service.client.auth.currentUser;
      if (currentUser != null) {
        await _handleGoogleSignInResult();
      }
    } catch (e) {
      if (!mounted) return;
      _showModernSnackBar('${t(context, 'googleSignInFailed')}: $e', isError: true);
    }
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
                color: const Color(0xFF86D8C8).withValues(alpha: 0.24),
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
                color: const Color(0xFF8AA8FF).withValues(alpha: 0.2),
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
                  child: AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
                      );
                    },
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
                            color: Colors.white.withValues(alpha: 0.62),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF7F9CCB,
                                ).withValues(alpha: 0.16),
                                blurRadius: 24,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox.shrink(), // Language button hidden - will be in settings
                              const SizedBox(height: 12),
                              Container(
                                width: 94,
                                height: 94,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF7C9CCB,
                                      ).withValues(alpha: 0.16),
                                      blurRadius: 20,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/image/Logo.jpeg',
                                    width: 94,
                                    height: 94,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: t(context, 'welcomeToSignIn'),
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF17324D),
                                        letterSpacing: -0.02,
                                        height: 1.25,
                                      ),
                                    ),
                                    TextSpan(
                                      text: t(context, 'splashTitle'),
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF00A79D),
                                        letterSpacing: -0.02,
                                        height: 1.25,
                                      ),
                                    ),
                                    TextSpan(
                                      text: t(context, 'physiotherapyApp'),
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF17324D),
                                        letterSpacing: -0.02,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t(context, 'signInSubtitle'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14.3,
                                  color: Color(0xFF6B7A90),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF8CA6C8,
                                      ).withValues(alpha: 0.12),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.phone_rounded,
                                            color: Color(0xFF00A79D),
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '+62',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF17324D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(13),
                                        ],
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: t(context, 'phoneNumber'),
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 14,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 16,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () async {
                                          final phone = _phoneController.text.trim();
                                          if (phone.isEmpty) {
                                            _showModernSnackBar(
                                              t(context, 'enterPhoneError'),
                                              isError: true,
                                            );
                                            return;
                                          }

                                          if (!_isValidIndonesianPhone(phone)) {
                                            _showModernSnackBar(
                                              t(context, 'validPhoneError'),
                                              isError: true,
                                            );
                                            return;
                                          }

                                          // NEW FLOW: Langsung ke OTP tanpa cek terdaftar
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => OtpVerificationScreen(
                                                phoneNumber: _normalizePhoneNumber(phone),
                                              ),
                                            ),
                                          );
                                        },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF00A79D),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          t(context, 'continuePhone'),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
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
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    child: Divider(color: Color(0xFFE2E8F0)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _signInWithGoogle,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF17324D,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFDCE7F5),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                          horizontal: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.55),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const GoogleLogoIcon(size: 22),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              t(context, 'continueGoogle'),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const OtpVerificationScreen(
                                                  phoneNumber: 'Apple Sign-In',
                                                ),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF17324D,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFDCE7F5),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                          horizontal: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.55),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.apple,
                                            color: Color(0xFF17324D),
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              t(context, 'continueApple'),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Sign Up link hidden - registration only via Google
                              const SizedBox.shrink(),
                            ],
                          ),
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
