import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../home/main_screen.dart';

class AccountCreatedScreen extends StatefulWidget {
  const AccountCreatedScreen({super.key});

  @override
  State<AccountCreatedScreen> createState() => _AccountCreatedScreenState();
}

class _AccountCreatedScreenState extends State<AccountCreatedScreen> {
  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        _goToHome();
      }
    });
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Logo Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Image.asset(
                    'assets/image/logo 2.png',
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'K E D O T A',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00A79D),
                      letterSpacing: 4.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'P H Y S I O T H E R A P Y',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00A79D).withValues(alpha: 0.85),
                      letterSpacing: 4.5,
                    ),
                  ),
                ],
              ),
            ).animate().fade(duration: 500.ms).slideY(begin: 0.2, curve: Curves.easeOutQuad),

            // White Card
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                  child: Column(
                    children: [
                      // Icon centang dalam lingkaran
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE8F6F4),
                          border: Border.all(
                            color: const Color(0xFF00A79D).withValues(alpha: 0.25),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF00A79D),
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Akun Berhasil Dibuat!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Selamat bergabung di Kedota Physiotherapy!\nAkun kamu sudah siap digunakan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Countdown bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: _countdown / 5,
                                    strokeWidth: 2.5,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    color: const Color(0xFF00A79D),
                                  ),
                                  Text(
                                    '$_countdown',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF00A79D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Text(
                              'Masuk ke beranda otomatis...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Tombol Masuk Beranda dengan gradient
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF007F78), Color(0xFF00A79D)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              _timer?.cancel();
                              _goToHome();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Masuk Beranda',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
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
