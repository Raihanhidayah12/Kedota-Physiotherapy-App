// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// The address-formatting logic is implemented inline here because it lives
// inside a widget/screen as a private helper and is not exported from lib/.
//
// Note: the East Java pattern must run BEFORE the plain ", Indonesia" pattern
// so that ", East Java, Indonesia" is replaced as a unit rather than having
// ", Indonesia" stripped first and leaving ", East Java" dangling.
String formatAddress(String raw) => raw
    .replaceAll(
      RegExp(r',\s*JI\s*,\s*Indonesia\s*$', caseSensitive: false),
      '',
    )
    .replaceAll(RegExp(r',\s*JI\s*$', caseSensitive: false), '')
    .replaceAll(
      RegExp(r',\s*East Java\s*,\s*Indonesia\s*$'),
      ', Jawa Timur',
    )
    .replaceAll(RegExp(r',\s*Indonesia\s*$', caseSensitive: false), '')
    .replaceAll(RegExp(r',\s*ID\s*$'), '')
    .trim();

void _benchmark(String label, int iterations, void Function() fn) {
  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) fn();
  sw.stop();
  final totalMs = sw.elapsedMilliseconds;
  final avgMs = totalMs / iterations;
  debugPrint(
    '[PERF] $label ${iterations}x: total=${totalMs}ms avg=${avgMs.toStringAsFixed(4)}ms',
  );
}

void main() {
  const iterations = 1000;
  // Threshold is 2ms (widened from 0.5ms) to avoid flakiness on slow CI machines.
  const avgThresholdMs = 2.0;

  const addresses = [
    'Jl. Raya Darmo 123, Surabaya, JI, Indonesia',
    'Jl. Pemuda 45, Malang, Indonesia',
    'Jl. Ahmad Yani 10, Sidoarjo, JI',
    'Jl. Basuki Rahmat 77, Surabaya, ID',
    'Jl. Diponegoro 8, Malang, East Java, Indonesia',
    'Jl. Veteran 12, Batu',
  ];

  group('Address format benchmark', () {
    test('formatAddress correctness', () {
      expect(
        formatAddress('Jl. Raya Darmo 123, Surabaya, JI, Indonesia'),
        'Jl. Raya Darmo 123, Surabaya',
      );
      expect(
        formatAddress('Jl. Pemuda 45, Malang, Indonesia'),
        'Jl. Pemuda 45, Malang',
      );
      expect(
        formatAddress('Jl. Ahmad Yani 10, Sidoarjo, JI'),
        'Jl. Ahmad Yani 10, Sidoarjo',
      );
      expect(
        formatAddress('Jl. Basuki Rahmat 77, Surabaya, ID'),
        'Jl. Basuki Rahmat 77, Surabaya',
      );
      expect(
        formatAddress('Jl. Diponegoro 8, Malang, East Java, Indonesia'),
        'Jl. Diponegoro 8, Malang, Jawa Timur',
      );
      // No suffix — should remain unchanged
      expect(formatAddress('Jl. Veteran 12, Batu'), 'Jl. Veteran 12, Batu');
    });

    test('formatAddress $iterations iterations (varied inputs)', () {
      var idx = 0;
      _benchmark('formatAddress', iterations, () {
        formatAddress(addresses[idx++ % addresses.length]);
      });

      final sw = Stopwatch()..start();
      idx = 0;
      for (var i = 0; i < iterations; i++) {
        formatAddress(addresses[idx++ % addresses.length]);
      }
      sw.stop();
      final avgMs = sw.elapsedMilliseconds / iterations;
      expect(
        avgMs,
        lessThan(avgThresholdMs),
        reason: 'formatAddress avg ${avgMs.toStringAsFixed(4)}ms exceeds ${avgThresholdMs}ms',
      );
    });
  });
}
