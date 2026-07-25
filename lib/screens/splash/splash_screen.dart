import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_language.dart';
import '../onboarding/onboarding_screen.dart';
import '../auth/google_profile_completion_screen.dart';
import '../auth/pin_verification_screen.dart';
import '../auth/sign_in_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Main orchestrator
  late AnimationController _masterController;

  // Logo & pulse rings
  late AnimationController _logoController;
  late AnimationController _pulseController;

  // Text animations
  late AnimationController _textController;

  // Background gradient animation
  late AnimationController _gradientController;

  // Exit animation (logo expand + background fill)
  late AnimationController _exitController;

  // Logo animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _exitLogoScale;
  late Animation<double> _backgroundFill;

  // Pulse ring animations
  late Animation<double> _pulse1Scale;
  late Animation<double> _pulse1Opacity;
  late Animation<double> _pulse2Scale;
  late Animation<double> _pulse2Opacity;
  late Animation<double> _pulse3Scale;
  late Animation<double> _pulse3Opacity;

  // Text animations (staggered reveal)
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleOpacity;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _taglineOpacity;

  // Gradient animation
  late Animation<double> _gradientProgress;

  @override
  void initState() {
    super.initState();

    // Master controller for orchestration
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    );

    // Logo entrance
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Pulse rings (looping, pero controlled by master)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Text reveals
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Background gradient flow
    _gradientController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);

    // Exit animation (logo expand + background fill)
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // ===== LOGO ANIMATIONS =====
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));

    // ===== PULSE RING ANIMATIONS (staggered ripples) =====
    _pulse1Scale = Tween<double>(begin: 0.6, end: 1.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    _pulse1Opacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    _pulse2Scale = Tween<double>(begin: 0.6, end: 1.8).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutQuad),
      ),
    );

    _pulse2Opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutQuad),
      ),
    );

    _pulse3Scale = Tween<double>(begin: 0.6, end: 1.8).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutQuad),
      ),
    );

    _pulse3Opacity = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutQuad),
      ),
    );

    // ===== TEXT ANIMATIONS (staggered slide + fade) =====
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _textController,
            curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.15, 1.0, curve: Curves.easeInOut),
      ),
    );

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );

    // ===== BACKGROUND GRADIENT ANIMATION =====
    _gradientProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.easeInOut),
    );

    // ===== EXIT ANIMATIONS (logo expand + background fill) =====
    _exitLogoScale = Tween<double>(begin: 1.0, end: 8.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    _backgroundFill = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    // ===== MASTER ORCHESTRATION =====
    _masterController.addListener(() {
      final progress = _masterController.value;

      // Logo entrance at 0%
      if (progress >= 0.0 &&
          _logoController.status == AnimationStatus.dismissed) {
        _logoController.forward();
      }

      // Text reveal at 25%
      if (progress >= 0.25 &&
          _textController.status == AnimationStatus.dismissed) {
        _textController.forward();
      }
    });

    _masterController.forward();

    // Trigger exit animation at 2100ms, then navigate after 600ms
    unawaited(
      Future.delayed(const Duration(milliseconds: 2100), () {
        if (!mounted) return;
        _exitController.forward();
      }),
    );

    unawaited(
      Future.delayed(const Duration(milliseconds: 2700), () async {
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

            final phone = (profile?['phone'] ?? session.user.userMetadata?['phone'] ?? '').toString().trim();
            final pinHash = (profile?['pin_hash'] ?? '').toString().trim();
            final isCompleteFlag = profile?['is_profile_complete'] == true;

            final isComplete = phone.isNotEmpty && (isCompleteFlag || pinHash.isNotEmpty);

            if (isComplete) {
              nextScreen = PinVerificationScreen(phoneNumber: phone);
            } else {
              final metadata = session.user.userMetadata ?? {};
              final email = session.user.email ?? profile?['email'] as String? ?? '';
              final fullName = metadata['full_name'] ?? metadata['name'] ?? profile?['full_name'] ?? '';

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
            transitionDuration: const Duration(milliseconds: 400),
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
    _pulseController.dispose();
    _textController.dispose();
    _gradientController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = (size.width < 380 ? size.width * 0.30 : size.width * 0.26)
        .clamp(108.0, 150.0);

    // Responsive typography tuned for a clean splash screen on phones and tablets
    final titleFontSize = (size.width < 380)
        ? size.width * 0.124
        : (size.width < 600)
        ? size.width * 0.108
        : size.width * 0.094;

    final subtitleFontSize = (size.width < 380)
        ? size.width * 0.086
        : (size.width < 600)
        ? size.width * 0.080
        : size.width * 0.072;

    final taglineFontSize = (size.width < 380)
        ? size.width * 0.036
        : (size.width < 600)
        ? size.width * 0.034
        : size.width * 0.030;

    final titleFontSizeClamped = titleFontSize.clamp(38.0, 64.0);
    final subtitleFontSizeClamped = subtitleFontSize.clamp(24.0, 36.0);
    final taglineFontSizeClamped = taglineFontSize.clamp(12.0, 18.0);

    // Responsive padding
    final horizontalPadding = (size.width < 380) ? 18.0 : 24.0;

    // Compact spacing that stays stable and visually tight
    final logoToTextSpacing = (size.width < 380) ? 2.0 : 3.0;
    final textToTextSpacing = (size.width < 380) ? 2.0 : 2.5;
    final textToTaglineSpacing = (size.width < 380) ? 2.0 : 2.5;

    return Scaffold(
      body: Stack(
        children: [
          // ===== ANIMATED BACKGROUND GRADIENT FLOW =====
          AnimatedBuilder(
            animation: _gradientProgress,
            builder: (context, _) {
              final progress = _gradientProgress.value;

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        const Color(0xFFFFFFFF),
                        const Color(0xFFF0FFFE),
                        progress,
                      )!,
                      Color.lerp(
                        const Color(0xFFE6F8F7),
                        const Color(0xFFDEF5F3),
                        progress,
                      )!,
                    ],
                  ),
                ),
              );
            },
          ),

          // ===== EXIT OVERLAY (TEAL FILL) =====
          AnimatedBuilder(
            animation: _backgroundFill,
            builder: (context, _) {
              return Container(
                color: const Color(
                  0xFF00A79D,
                ).withValues(alpha: _backgroundFill.value * 0.95),
              );
            },
          ),

          // ===== MAIN CONTENT =====
          SafeArea(
            child: Stack(
              children: [
                // ===== TOP DECORATIVE ACCENT =====
                Positioned(
                  top: 0,
                  right: 0,
                  child: Opacity(
                    opacity: 0.08,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00A79D),
                      ),
                    ),
                  ),
                ),

                // ===== MAIN CENTERED CONTENT =====
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ===== LOGO WITH PULSE RINGS =====
                          SizedBox(
                            width: logoSize * 2.2,
                            height: logoSize * 2.2,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulse Ring 1 (first ripple)
                                AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _pulse1Scale,
                                    _backgroundFill,
                                  ]),
                                  builder: (context, _) {
                                    return Opacity(
                                      opacity:
                                          (1.0 - _backgroundFill.value) * 0.6,
                                      child: Transform.scale(
                                        scale: _pulse1Scale.value,
                                        child: Container(
                                          width: logoSize,
                                          height: logoSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF00A79D)
                                                  .withValues(
                                                    alpha:
                                                        _pulse1Opacity.value *
                                                        0.6,
                                                  ),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // Pulse Ring 2 (second ripple)
                                AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _pulse2Scale,
                                    _backgroundFill,
                                  ]),
                                  builder: (context, _) {
                                    return Opacity(
                                      opacity:
                                          (1.0 - _backgroundFill.value) * 0.4,
                                      child: Transform.scale(
                                        scale: _pulse2Scale.value,
                                        child: Container(
                                          width: logoSize,
                                          height: logoSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF00A79D)
                                                  .withValues(
                                                    alpha:
                                                        _pulse2Opacity.value *
                                                        0.4,
                                                  ),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // Pulse Ring 3 (third ripple)
                                AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _pulse3Scale,
                                    _backgroundFill,
                                  ]),
                                  builder: (context, _) {
                                    return Opacity(
                                      opacity:
                                          (1.0 - _backgroundFill.value) * 0.2,
                                      child: Transform.scale(
                                        scale: _pulse3Scale.value,
                                        child: Container(
                                          width: logoSize,
                                          height: logoSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF00A79D)
                                                  .withValues(
                                                    alpha:
                                                        _pulse3Opacity.value *
                                                        0.2,
                                                  ),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // Logo Image (center)
                                AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _logoScale,
                                    _logoOpacity,
                                    _exitLogoScale,
                                  ]),
                                  builder: (context, _) {
                                    final baseScale = _logoScale.value;
                                    final exitScale = _exitLogoScale.value;
                                    final combinedScale = baseScale * exitScale;

                                    return Opacity(
                                      opacity:
                                          _logoOpacity.value *
                                          (1.0 - _backgroundFill.value),
                                      child: Transform.scale(
                                        scale: combinedScale,
                                        child: Container(
                                          width: logoSize,
                                          height: logoSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF00A79D,
                                                ).withValues(alpha: 0.25),
                                                blurRadius: 40,
                                                spreadRadius: 8,
                                                offset: const Offset(0, 15),
                                              ),
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF00A79D,
                                                ).withValues(alpha: 0.12),
                                                blurRadius: 20,
                                                spreadRadius: 0,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.all(12),
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
                              ],
                            ),
                          ),

                          SizedBox(height: logoToTextSpacing),

                          // ===== TEXT CONTENT (STAGGERED REVEAL) =====
                          AnimatedBuilder(
                            animation: _backgroundFill,
                            builder: (context, _) {
                              return Opacity(
                                opacity: 1.0 - _backgroundFill.value,
                                child: SlideTransition(
                                  position: _titleSlide,
                                  child: FadeTransition(
                                    opacity: _titleOpacity,
                                    child: Text(
                                      t(context, 'splashTitle'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: titleFontSizeClamped,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF00A79D),
                                        height: 0.85,
                                        letterSpacing: -0.6,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: textToTextSpacing),

                          AnimatedBuilder(
                            animation: _backgroundFill,
                            builder: (context, _) {
                              return Opacity(
                                opacity: 1.0 - _backgroundFill.value,
                                child: SlideTransition(
                                  position: _subtitleSlide,
                                  child: FadeTransition(
                                    opacity: _subtitleOpacity,
                                    child: Transform.translate(
                                      offset: const Offset(0, -6),
                                      child: Text(
                                        t(context, 'splashSubtitle'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: subtitleFontSizeClamped,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF333333),
                                          letterSpacing: 0.0,
                                          height: 0.95,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: textToTaglineSpacing),

                          AnimatedBuilder(
                            animation: _backgroundFill,
                            builder: (context, _) {
                              return Opacity(
                                opacity: 1.0 - _backgroundFill.value,
                                child: FadeTransition(
                                  opacity: _taglineOpacity,
                                  child: Text(
                                    t(context, 'splashTagline'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: taglineFontSizeClamped,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF667A7A),
                                      letterSpacing: 0.15,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ===== BOTTOM DECORATIVE ACCENT =====
                Positioned(
                  bottom: -50,
                  left: -80,
                  child: Opacity(
                    opacity: 0.06,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00A79D),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
