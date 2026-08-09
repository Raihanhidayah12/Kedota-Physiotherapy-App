import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_language.dart';
import '../auth/sign_in_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  List<_OnboardingPageData> _pages(BuildContext context) => [
    _OnboardingPageData(
      title: "Pesan Jadwal Tanpa Ribet!",
      description: "Atur Jadwal Konsultasi dengan\nGampang dan Efisien!",
      imagePath: 'assets/image/Boarding/boarding 1.png',
    ),
    _OnboardingPageData(
      title: "Pantau Kesehatan Lebih Mudah",
      description: "Monitor Perkembangan Vital-mu\nSecara Real-time",
      imagePath: null, // Shows mockup placeholder box if no asset
    ),
    _OnboardingPageData(
      title: "Perawatan Medis Dirumah Anda",
      description: "Atur Jadwal Untuk Melakukan\nPerawatan Medis Dirumah",
      imagePath: null, // Shows mockup placeholder box if no asset
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
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
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                      .chain(CurveTween(curve: Curves.easeOutCubic))
                      .animate(curvedAnimation),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1)
                    .chain(CurveTween(curve: Curves.easeOutCubic))
                    .animate(curvedAnimation),
                child: child,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ===== HEADER BAR (BACK BUTTON & SKIP BUTTON) =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Arrow Button (Shown on Screen 2 & 3)
                    if (_currentPage > 0)
                      IconButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOutCubic,
                          );
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFF1E293B),
                          size: 22,
                        ),
                        tooltip: t(context, 'back'),
                      )
                    else
                      const SizedBox(width: 48),

                    // Skip ("Lewati") Button (Shown on Screen 1 & 2)
                    if (_currentPage < pages.length - 1)
                      TextButton(
                        onPressed: _completeOnboardingAndNavigate,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00A79D),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Text(
                          t(context, 'skip'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00A79D),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // ===== SWIPEABLE PAGE VIEW CONTENT =====
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = pages[index];

                  return Column(
                    children: [
                      // HERO GRAPHIC / IMAGE AREA
                      Expanded(
                        flex: 6,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: page.imagePath != null
                                ? Image.asset(
                                    page.imagePath!,
                                    fit: BoxFit.contain,
                                  )
                                : Container(
                                    width: 220,
                                    height: 220,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFCBD5E1,
                                      ).withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_outlined,
                                        size: 64,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      // TITLE & DESCRIPTION TEXT
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),

                              // Title Text
                              Text(
                                page.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  height: 1.25,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Subtitle / Description Text
                              Text(
                                page.description,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                  height: 1.45,
                                ),
                              ),

                              const Spacer(),

                              // DOT INDICATORS (Placed directly above bottom button)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(pages.length, (i) {
                                  final isActive = _currentPage == i;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    width: isActive ? 24 : 8,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? const Color(0xFF00A79D)
                                          : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ===== FULL-WIDTH BOTTOM ACTION BUTTON ("Lanjut" / "Mulai") =====
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                      );
                    } else {
                      _completeOnboardingAndNavigate();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A79D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    _currentPage < pages.length - 1
                        ? t(context, 'next')
                        : t(context, 'getStarted'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String description;
  final String? imagePath;

  const _OnboardingPageData({
    required this.title,
    required this.description,
    this.imagePath,
  });
}
