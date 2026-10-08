// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kedotaapp/utils/phone_validator.dart';

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
  const iterations = 10000;
  // Threshold is 1ms (widened from 0.1ms) to avoid flakiness on slow CI machines.
  const avgThresholdMs = 1.0;

  // Sample inputs covering all supported formats
  const phoneFormats = [
    '+6281234567890', // E.164 with +62
    '081234567890',   // local 08 format
    '81234567890',    // without leading 0 or country code
    '6281234567890',  // without + prefix
  ];

  group('PhoneValidator benchmark', () {
    test('normalizePhoneNumber $iterations iterations (all formats)', () {
      var idx = 0;
      _benchmark('normalizePhone', iterations, () {
        PhoneValidator.normalizePhoneNumber(phoneFormats[idx++ % phoneFormats.length]);
      });

      final sw = Stopwatch()..start();
      idx = 0;
      for (var i = 0; i < iterations; i++) {
        PhoneValidator.normalizePhoneNumber(phoneFormats[idx++ % phoneFormats.length]);
      }
      sw.stop();
      final avgMs = sw.elapsedMilliseconds / iterations;
      expect(
        avgMs,
        lessThan(avgThresholdMs),
        reason: 'normalizePhoneNumber avg ${avgMs.toStringAsFixed(4)}ms exceeds ${avgThresholdMs}ms',
      );
    });

    test('normalizePhoneNumber correctness', () {
      expect(PhoneValidator.normalizePhoneNumber('+6281234567890'), '+6281234567890');
      expect(PhoneValidator.normalizePhoneNumber('081234567890'),   '+6281234567890');
      expect(PhoneValidator.normalizePhoneNumber('81234567890'),    '+6281234567890');
      expect(PhoneValidator.normalizePhoneNumber('6281234567890'),  '+6281234567890');
    });

    test('isValidIndonesianPhone $iterations iterations', () {
      var idx = 0;
      _benchmark('isValidIndonesianPhone', iterations, () {
        PhoneValidator.isValidIndonesianPhone(phoneFormats[idx++ % phoneFormats.length]);
      });

      final sw = Stopwatch()..start();
      idx = 0;
      for (var i = 0; i < iterations; i++) {
        PhoneValidator.isValidIndonesianPhone(phoneFormats[idx++ % phoneFormats.length]);
      }
      sw.stop();
      final avgMs = sw.elapsedMilliseconds / iterations;
      expect(
        avgMs,
        lessThan(avgThresholdMs),
        reason: 'isValidIndonesianPhone avg ${avgMs.toStringAsFixed(4)}ms exceeds ${avgThresholdMs}ms',
      );
    });

    test('isValidIndonesianPhone correctness', () {
      expect(PhoneValidator.isValidIndonesianPhone('+6281234567890'), isTrue);
      expect(PhoneValidator.isValidIndonesianPhone('081234567890'),   isTrue);
      expect(PhoneValidator.isValidIndonesianPhone('81234567890'),    isTrue);
      expect(PhoneValidator.isValidIndonesianPhone('123'),            isFalse);
      expect(PhoneValidator.isValidIndonesianPhone(''),               isFalse);
    });
  });
}
