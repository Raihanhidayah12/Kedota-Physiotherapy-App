// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kedotaapp/utils/rest_crypto.dart';

// Synthetic test keys — NOT sourced from .env.
// REST_ENCRYPT_KEY: 64 hex chars = 32 bytes (AES-256)
// REST_HMAC_KEY:    66 hex chars = 33 bytes (HMAC-SHA256, >= 32 bytes required)
const _testEnv = '''
REST_ENCRYPT_KEY=deadbeefcafebabe0123456789abcdef0123456789abcdef0123456789abcdef
REST_HMAC_KEY=feedfacedeadbeefcafebabefeedface0123456789abcdef0123456789abcdef01
''';

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
  setUpAll(() {
    // Load synthetic keys — overrides any previously loaded dotenv state.
    dotenv.testLoad(fileInput: _testEnv);
  });

  const iterations = 1000;
  // Threshold is 10ms (widened from 5ms) to avoid flakiness on slow CI machines.
  const avgThresholdMs = 10.0;

  final samplePayload = <String, dynamic>{
    'user_id': 'usr-0000-1111-2222',
    'phone': '+6281234567890',
    'pin_hash': '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
    'action': 'verify_pin',
  };

  group('RestCrypto benchmark', () {
    test('encryptPayload $iterations iterations', () {
      double avgMs = 0;
      _benchmark('encryptPayload', iterations, () {
        RestCrypto.encryptPayload(samplePayload);
      });
      // Measure again cleanly for assertion
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        RestCrypto.encryptPayload(samplePayload);
      }
      sw.stop();
      avgMs = sw.elapsedMilliseconds / iterations;
      expect(
        avgMs,
        lessThan(avgThresholdMs),
        reason: 'encryptPayload avg ${avgMs.toStringAsFixed(4)}ms exceeds ${avgThresholdMs}ms',
      );
    });

    test('decryptPayload $iterations iterations', () {
      // Pre-generate envelopes so decryption timing is isolated.
      final envelopes = List.generate(
        iterations,
        (_) => RestCrypto.encryptPayload(samplePayload),
      );

      double avgMs = 0;
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        RestCrypto.decryptPayload(envelopes[i]);
      }
      sw.stop();
      avgMs = sw.elapsedMilliseconds / iterations;
      debugPrint(
        '[PERF] decryptPayload ${iterations}x: total=${sw.elapsedMilliseconds}ms avg=${avgMs.toStringAsFixed(4)}ms',
      );
      expect(
        avgMs,
        lessThan(avgThresholdMs),
        reason: 'decryptPayload avg ${avgMs.toStringAsFixed(4)}ms exceeds ${avgThresholdMs}ms',
      );
    });

    test('encryptSensitiveFields $iterations iterations', () {
      double avgMs = 0;
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        RestCrypto.encryptSensitiveFields(samplePayload);
      }
      sw.stop();
      avgMs = sw.elapsedMilliseconds / iterations;
      debugPrint(
        '[PERF] encryptSensitiveFields ${iterations}x: total=${sw.elapsedMilliseconds}ms avg=${avgMs.toStringAsFixed(4)}ms',
      );
      expect(
        avgMs,
        lessThan(avgThresholdMs),
        reason: 'encryptSensitiveFields avg ${avgMs.toStringAsFixed(4)}ms exceeds ${avgThresholdMs}ms',
      );
    });

    test('decryptSensitiveFields $iterations iterations', () {
      // Pre-encrypt so decryption timing is isolated.
      final encrypted = List.generate(
        iterations,
        (_) => RestCrypto.encryptSensitiveFields(samplePayload),
      );

      double avgMs = 0;
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        RestCrypto.decryptSensitiveFields(encrypted[i]);
      }
      sw.stop();
      avgMs = sw.elapsedMilliseconds / iterations;
      debugPrint(
        '[PERF] decryptSensitiveFields ${iterations}x: total=${sw.elapsedMilliseconds}ms avg=${avgMs.toStringAsFixed(4)}ms',
      );
      expect(
        avgMs,
        lessThan(avgThresholdMs),
        reason: 'decryptSensitiveFields avg ${avgMs.toStringAsFixed(4)}ms exceeds ${avgThresholdMs}ms',
      );
    });
  });
}
