import 'dart:async';
import 'package:flutter/material.dart';
import '../home/home_screen.dart';

class AccountCreatedScreen extends StatefulWidget {
  const AccountCreatedScreen({super.key});

  @override
  State<AccountCreatedScreen> createState() => _AccountCreatedScreenState();
}

class _AccountCreatedScreenState extends State<AccountCreatedScreen>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final AnimationController _fadeController;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;
  late final Animation<double> _fadeIn;

  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Animasi lingkaran check muncul
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _checkOpacity = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeIn,
    );
    _fadeIn = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Start animasi
    _checkController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fadeController.forward();
    });

    // Countdown 5 detik lalu ke HomeScreen
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown--;
      });
      if (_countdown <= 0) {
        timer.cancel();
        _goToHome();
      }
    });
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _checkController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: Stack(
          children: [
            // Dekorasi lingkaran latar
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
            // Konten utama
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon centang animasi
                      ScaleTransition(
                        scale: _checkScale,
                        child: FadeTransition(
                          opacity: _checkOpacity,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00A79D).withValues(alpha: 0.12),
                              border: Border.all(
                                color: const Color(0xFF00A79D).withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF00A79D),
                              size: 72,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Teks
                      FadeTransition(
                        opacity: _fadeIn,
                        child: Column(
                          children: [
                            const Text(
                              'Akun Berhasil Dibuat!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF17324D),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Selamat bergabung! Akun kamu sudah siap digunakan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF64748B),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Countdown
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFDCE7F5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7F9CCB).withValues(alpha: 0.1),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: _countdown / 5,
                                          strokeWidth: 3,
                                          backgroundColor: const Color(0xFFE2E8F0),
                                          color: const Color(0xFF00A79D),
                                        ),
                                        Text(
                                          '$_countdown',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF00A79D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Masuk ke beranda otomatis...',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Tombol langsung masuk
                            TextButton(
                              onPressed: () {
                                _timer?.cancel();
                                _goToHome();
                              },
                              child: const Text(
                                'Langsung Masuk →',
                                style: TextStyle(
                                  color: Color(0xFF00A79D),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
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
          ],
        ),
      ),
    );
  }
}
