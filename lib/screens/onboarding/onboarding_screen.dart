import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import '../../l10n/app_language.dart';
import '../../widgets/language_button.dart';
import '../auth/sign_in_screen.dart' hide Text;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  int _currentPage = 0;
  double _pageValue = 0.0;
  late final AnimationController _decorController;

  List<_OnboardingPageData> _pages(BuildContext context) => [
    _OnboardingPageData(
      title: t(context, 'welcomeTo'),
      subtitle: t(context, 'kedotaPhysiotherapy'),
      description: t(context, 'onboardingWelcomeDesc'),
      icon: Icons.favorite_rounded,
      color: const Color(0xFF00A79D),
      accentColor: const Color(0xFFE6F8F7),
    ),
    _OnboardingPageData(
      title: t(context, 'recoveryWith'),
      subtitle: t(context, 'guidance'),
      description: t(context, 'onboardingRecoveryDesc'),
      icon: Icons.accessibility_new_rounded,
      color: const Color(0xFF00A79D),
      accentColor: const Color(0xFFE6F8F7),
    ),
    _OnboardingPageData(
      title: t(context, 'startYour'),
      subtitle: t(context, 'journey'),
      description: t(context, 'onboardingJourneyDesc'),
      icon: Icons.self_improvement_rounded,
      color: const Color(0xFF00A79D),
      accentColor: const Color(0xFFE6F8F7),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _decorController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _pageController.addListener(() {
      final next = _pageController.page;
      if (next == null) return;
      if ((next - _pageValue).abs() < 0.001) return;
      setState(() => _pageValue = next);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _decorController.dispose();
    super.dispose();
  }

  void _completeOnboardingAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const SignInScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.04),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          final scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: offsetAnimation,
              child: ScaleTransition(scale: scaleAnimation, child: child),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 750),
        reverseTransitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pages = _pages(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF00A79D), const Color(0xFF00A79D)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Animated background decorative elements
              Positioned(
                top: 20,
                right: -80,
                child: AnimatedBuilder(
                  animation: _decorController,
                  builder: (context, _) {
                    return Transform.rotate(
                      angle: _decorController.value * 2 * math.pi,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF00A79D).withValues(alpha: 0.06),
                              const Color(0xFF00A79D).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: -60,
                left: -60,
                child: AnimatedBuilder(
                  animation: _decorController,
                  builder: (context, _) {
                    return Transform.rotate(
                      angle: -_decorController.value * 1.5 * math.pi,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF00A79D).withValues(alpha: 0.05),
                              const Color(0xFF00A79D).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Main content
              Column(
                children: [
                  // Header with skip button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFF00A79D,
                            ).withValues(alpha: 0.1),
                          ),
                          child: Center(
                            child: Text(
                              '${_currentPage + 1}/${pages.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox.shrink(), // Language button hidden - will be in settings
                        TextButton(
                          onPressed: () {
                            _completeOnboardingAndNavigate();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                          child: Text(
                            t(context, 'skip'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expanded content area
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pages.length,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        final page = pages[index];
                        final delta = (_pageValue - index).abs().clamp(
                          0.0,
                          1.0,
                        );

                        final scale = 0.82 + ((1 - delta) * 0.18);
                        final opacity = 0.35 + ((1 - delta) * 0.65);
                        final translateY = (index - _pageValue) * 34;

                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            final pageOffset =
                                (_pageController.hasClients &&
                                    _pageController.page != null)
                                ? (_pageController.page! - index).clamp(
                                    -1.0,
                                    1.0,
                                  )
                                : 0.0;

                            final slideOffset = pageOffset * 40.0;
                            final fadeValue = (1 - pageOffset.abs()).clamp(
                              0.0,
                              1.0,
                            );

                            return Transform.translate(
                              offset: Offset(slideOffset, 0),
                              child: Opacity(
                                opacity: fadeValue,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Transform.translate(
                                          offset: Offset(0, translateY),
                                          child: AnimatedOpacity(
                                            opacity: opacity,
                                            duration: const Duration(
                                              milliseconds: 500,
                                            ),
                                            curve: Curves.easeOutBack,
                                            child: Transform.scale(
                                              scale: scale,
                                              child: LayoutBuilder(
                                                builder: (context, constraints) {
                                                  // Responsive sizing based on available space
                                                  final maxSize =
                                                      constraints.maxHeight *
                                                      0.75;
                                                  final containerSize =
                                                      (maxSize * 0.75).clamp(
                                                        120.0,
                                                        150.0,
                                                      );
                                                  final glowSize =
                                                      (maxSize * 0.95).clamp(
                                                        160.0,
                                                        200.0,
                                                      );
                                                  final iconSize =
                                                      (containerSize * 0.5)
                                                          .clamp(60.0, 75.0);

                                                  return Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      // Outer glow ring
                                                      Container(
                                                        width: glowSize,
                                                        height: glowSize,
                                                        decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          gradient: RadialGradient(
                                                            colors: [
                                                              page.color
                                                                  .withValues(
                                                                    alpha: 0.08,
                                                                  ),
                                                              page.color
                                                                  .withValues(
                                                                    alpha: 0.0,
                                                                  ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      // Main icon container
                                                      Container(
                                                        width: containerSize,
                                                        height: containerSize,
                                                        decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: page.color,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: page.color
                                                                  .withValues(
                                                                    alpha: 0.24,
                                                                  ),
                                                              blurRadius: 30,
                                                              spreadRadius: 6,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    10,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Icon(
                                                          page.icon,
                                                          size: iconSize,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 600,
                                          ),
                                          switchInCurve: Curves.easeOutBack,
                                          switchOutCurve: Curves.easeInCubic,
                                          transitionBuilder:
                                              (child, animation) {
                                                final transitionValue =
                                                    animation.value.clamp(
                                                      0.0,
                                                      1.0,
                                                    );

                                                return FadeTransition(
                                                  opacity: animation,
                                                  child: SlideTransition(
                                                    position: Tween<Offset>(
                                                      begin: const Offset(
                                                        0,
                                                        0.14,
                                                      ),
                                                      end: Offset.zero,
                                                    ).animate(animation),
                                                    child: Transform.scale(
                                                      scale:
                                                          0.96 +
                                                          transitionValue *
                                                              0.04,
                                                      child: child,
                                                    ),
                                                  ),
                                                );
                                              },
                                          child: Column(
                                            key: ValueKey<String>(
                                              '${page.title}-${page.subtitle}',
                                            ),
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                page.title,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: size.width < 380
                                                      ? 20
                                                      : 22,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.85),
                                                  letterSpacing: 0.1,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                page.subtitle,
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: size.width < 380
                                                      ? 26
                                                      : 28,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                  letterSpacing: -0.3,
                                                  height: 1.2,
                                                ),
                                              ),
                                              const SizedBox(height: 18),
                                              Text(
                                                page.description,
                                                textAlign: TextAlign.center,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: size.width < 380
                                                      ? 13
                                                      : 14,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.8),
                                                  height: 1.5,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Bottom section - dots & button
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      size.width < 380 ? 20 : 28,
                      20,
                      size.width < 380 ? 16 : 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated progress indicator
                        SizedBox(
                          height: 5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2.5),
                            child: Stack(
                              children: [
                                // Background track
                                Container(
                                  width: double.infinity,
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                                // Progress bar
                                FractionallySizedBox(
                                  widthFactor:
                                      (_currentPage + 1) / pages.length,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: size.width < 380 ? 18 : 24),

                        // CTA Buttons
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Row(
                            key: ValueKey<int>(_currentPage),
                            children: [
                              if (_currentPage > 0)
                                Expanded(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                    margin: const EdgeInsets.only(right: 12),
                                    child: OutlinedButton(
                                      onPressed: () {
                                        _pageController.previousPage(
                                          duration: const Duration(
                                            milliseconds: 650,
                                          ),
                                          curve: Curves.easeOutCubic,
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Colors.white,
                                          width: 1.2,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          vertical: size.width < 380 ? 13 : 15,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        t(context, 'back'),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_currentPage < pages.length - 1) {
                                      _pageController.nextPage(
                                        duration: const Duration(
                                          milliseconds: 650,
                                        ),
                                        curve: Curves.easeOutCubic,
                                      );
                                    } else {
                                      _completeOnboardingAndNavigate();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF00A79D),
                                    padding: EdgeInsets.symmetric(
                                      vertical: size.width < 380 ? 13 : 15,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Text(
                                      _currentPage < pages.length - 1
                                          ? t(context, 'next')
                                          : t(context, 'getStarted'),
                                      key: ValueKey<String>(
                                        _currentPage < pages.length - 1
                                            ? 'next'
                                            : 'started',
                                      ),
                                      style: TextStyle(
                                        fontSize: size.width < 380 ? 15 : 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: size.width < 380 ? 10 : 14),

                        // Dot indicators (alternative visual)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(pages.length, (index) {
                            final isActive = _currentPage == index;
                            final nextActive = _currentPage + 1 == index;

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: isActive
                                    ? 24
                                    : nextActive
                                    ? 10
                                    : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(3.5),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF00A79D,
                                            ).withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            spreadRadius: 0,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final Color accentColor;

  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.accentColor,
  });
}
