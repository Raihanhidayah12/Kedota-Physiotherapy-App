import 'package:flutter/material.dart';

/// Widget error state untuk data gagal dimuat.
/// Tampilan: icon refresh dalam circle → teks bold merah → subtitle abu → opsional tombol retry.
///
/// Penggunaan:
/// ```dart
/// DataErrorWidget(onRetry: () => _loadData())
/// DataErrorWidget(
///   title: 'Gagal Memuat Data',
///   subtitle: 'Silahkan refresh halaman',
///   onRetry: () => _loadData(),
/// )
/// ```
class DataErrorWidget extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final VoidCallback? onRetry;

  const DataErrorWidget({
    super.key,
    this.title,
    this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = title ?? 'Gagal Memuat Data';
    final displaySubtitle = subtitle ?? 'Silahkan refresh halaman';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Icon refresh dalam circle ──────────────────────────────────
          GestureDetector(
            onTap: onRetry,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFF00A79D),
                  size: 36,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Judul ──────────────────────────────────────────────────────
          Text(
            displayTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFFD94F45),
            ),
          ),
          const SizedBox(height: 8),

          // ── Subtitle ───────────────────────────────────────────────────
          Text(
            displaySubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8AA8AC),
              height: 1.4,
            ),
          ),

          // ── Tombol retry (opsional) ────────────────────────────────────
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00A79D),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
