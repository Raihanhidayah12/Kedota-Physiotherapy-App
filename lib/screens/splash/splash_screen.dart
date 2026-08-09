import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_language.dart';
import '../onboarding/onboarding_screen.dart';
import '../auth/google_profile_completion_screen.dart';
import '../auth/pin_verification_screen.dart';
import '../auth/sign_in_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Main orchestrator
  late AnimationController _masterController;

  // Logo entrance animation
  late AnimationController _logoController;

  // Text reveal animation
  late AnimationController _textController;

  // Exit animation (Zoom logo to white screen)
  late AnimationController _exitController;

  // Logo entrance animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // Exit animations
  late Animation<double> _exitLogoScale;
  late Animation<double> _whiteOverlayOpacity;
  late Animation<double> _textExitOpacity;

  // Text reveal animations
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleOpacity;
  late Animation<Offset> _subtitleSlide;

  Timer? _exitTimer;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // Master controller for orchestration
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );

    // Logo entrance (spring pop-in curve)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );

    // Text reveals
    _textController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    // Exit animation (Ultra smooth zoom logo to full white)
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 750),
      vsync: this,
    );

    // ===== LOGO ENTRANCE =====
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // ===== TEXT REVEALS =====
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _textController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
      ),
    );

    // ===== ULTRA SMOOTH EXIT (ZOOM LOGO TO FULL WHITE SCREEN) =====
    _exitLogoScale = Tween<double>(begin: 1.0, end: 40.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOutCubic),
    );

    _whiteOverlayOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeInOut),
      ),
    );

    _textExitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    // ===== MASTER ORCHESTRATION =====
    _masterController.addListener(() {
      final progress = _masterController.value;

      if (progress >= 0.0 &&
          _logoController.status == AnimationStatus.dismissed) {
        _logoController.forward();
      }

      if (progress >= 0.25 &&
          _textController.status == AnimationStatus.dismissed) {
        _textController.forward();
      }
    });

    _masterController.forward();

    // Trigger exit zoom after 2100ms
    unawaited(
      Future.delayed(const Duration(milliseconds: 2100), () {
        if (!mounted) return;
        _exitController.forward();
      }),
    );

    // Execute navigation after zoom to full white screen completes
    unawaited(
      Future.delayed(const Duration(milliseconds: 2850), () async {
        if (!mounted) return;

        // Check user session and onboarding status
        final prefs = await SharedPreferences.getInstance();
        final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
        final session = Supabase.instance.client.auth.currentSession;

        Widget nextScreen;
        if (session != null) {
          try {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', session.user.id)
                .maybeSingle();

            final phone = (profile?['phone'] ?? '').toString().trim();
            final pinHash = (profile?['pin_hash'] ?? '').toString().trim();
            final isCompleteFlag = profile?['is_profile_complete'] == true;

            // Hanya dianggap complete kalau phone DAN pin_hash ada di profiles table
            // Tidak pakai userMetadata['phone'] karena Google bisa isi itu tapi
            // user belum tentu sudah selesai registrasi di app kita
            final isComplete = phone.isNotEmpty && pinHash.isNotEmpty;

            if (isComplete) {
              nextScreen = PinVerificationScreen(phoneNumber: phone);
            } else {
              final metadata = session.user.userMetadata ?? {};
              final email =
                  session.user.email ?? profile?['email'] as String? ?? '';
              final fullName = metadata['full_name'] ??
                  metadata['name'] ??
                  profile?['full_name'] ??
                  '';

              nextScreen = GoogleProfileCompletionScreen(
                email: email,
                initialFullName: fullName.toString(),
                initialPhone: phone,
              );
            }
          } catch (e) {
            debugPrint('Splash check error: $e');
            nextScreen = const SignInScreen();
          }
        } else if (hasSeenOnboarding) {
          nextScreen = const SignInScreen();
        } else {
          nextScreen = const OnboardingScreen();
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => nextScreen,
            transitionDuration: const Duration(milliseconds: 350),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    _masterController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Responsive logo size
    final logoSize = (size.width < 380 ? size.width * 0.32 : size.width * 0.28)
        .clamp(120.0, 160.0);

    final titleFontSize = (size.width < 380) ? 42.0 : 48.0;
    final subtitleFontSize = (size.width < 380) ? 13.0 : 15.0;

    return Scaffold(
      body: Stack(
        children: [
          // ===== MAIN BRAND GREEN BACKGROUND =====
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF00A79D), // Pure full brand green background
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ===== PURE LOGO (NO SHADOW & NO WHITE OUTLINE BORDER) =====
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _logoScale,
                          _logoOpacity,
                          _exitLogoScale,
                        ]),
                        builder: (context, _) {
                          final combinedScale =
                              _logoScale.value * _exitLogoScale.value;

                          return Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: combinedScale,
                              child: SizedBox(
                                width: logoSize,
                                height: logoSize,
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/image/Logo.jpeg',
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // ===== BRAND TEXT =====
                      AnimatedBuilder(
                        animation: _textExitOpacity,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _textExitOpacity.value,
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            // Title: "Kedota"
                            SlideTransition(
                              position: _titleSlide,
                              child: FadeTransition(
                                opacity: _titleOpacity,
                                child: Text(
                                  t(context, 'splashTitle'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.0,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Subtitle: "PHYSIOTHERAPY" (With wide letter spacing)
                            SlideTransition(
                              position: _subtitleSlide,
                              child: FadeTransition(
                                opacity: _subtitleOpacity,
                                child: Text(
                                  t(context, 'splashSubtitle').toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: subtitleFontSize,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.92),
                                    letterSpacing: 5.5, // Spaced letters
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ===== WHITE OVERLAY FOR FULL WHITE SCREEN AT EXIT =====
          AnimatedBuilder(
            animation: _whiteOverlayOpacity,
            builder: (context, _) {
              return IgnorePointer(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.white.withValues(alpha: _whiteOverlayOpacity.value),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
