import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/app_language.dart';

class ServerDownScreen extends StatefulWidget {
  const ServerDownScreen({super.key, required this.onRetry});

  final Future<bool> Function() onRetry;

  @override
  State<ServerDownScreen> createState() => _ServerDownScreenState();
}

class _ServerDownScreenState extends State<ServerDownScreen> {
  bool _isChecking = false;

  Future<void> _checkServer() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    final stopwatch = Stopwatch()..start();
    try {
      await widget.onRetry();
    } finally {
      // Pastikan ada jeda animasi loading minimal 1.2 detik agar terasa proses pengecekannya
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 1200) {
        await Future.delayed(Duration(milliseconds: 1200 - elapsed));
      }
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxImageHeight = (constraints.maxHeight * 0.36)
                .clamp(160.0, 300.0)
                .toDouble();

            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Ilustrasi server error dengan animasi floating halus
                            Image.asset(
                              'assets/image/eror.png',
                              height: maxImageHeight,
                              fit: BoxFit.contain,
                            )
                                .animate(
                                  onPlay: (controller) =>
                                      controller.repeat(reverse: true),
                                )
                                .moveY(
                                  begin: -8,
                                  end: 8,
                                  duration: 2200.ms,
                                  curve: Curves.easeInOut,
                                ),

                            const SizedBox(height: 24),

                            // Judul Gangguan Server
                            Text(
                              t(context, 'serverDownTitle'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF00A79D),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                                .animate()
                                .fade(duration: 400.ms)
                                .slideY(begin: 0.1, curve: Curves.easeOutQuad),

                            const SizedBox(height: 8),

                            // Subtitle penjelasan
                            Text(
                              t(context, 'serverDownSubtitle'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF687782),
                                fontSize: 13,
                                height: 1.45,
                              ),
                            )
                                .animate()
                                .fade(delay: 150.ms, duration: 400.ms)
                                .slideY(begin: 0.1, curve: Curves.easeOutQuad),

                            const SizedBox(height: 6),

                            // Tips tambahan
                            Text(
                              t(context, 'serverDownTip'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            )
                                .animate()
                                .fade(delay: 250.ms, duration: 400.ms)
                                .slideY(begin: 0.1, curve: Curves.easeOutQuad),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Tombol Coba Lagi
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isChecking ? null : _checkServer,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF008F87),
                        disabledBackgroundColor: const Color(0xFF008F87),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              t(context, 'retry'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
