// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kedotaapp/utils/booking_code.dart';

// ── Inline medical-code generator ────────────────────────────────────────────
// The production _generateMedicalCode is a private async method on
// SupabaseAuthService that hits the database for uniqueness checks.
// We benchmark the pure generation logic inline (same algorithm, no I/O).
String _generateMedicalCode() {
  final now = DateTime.now();
  final year = now.year.toString().substring(2); // 2-digit year
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  final seq = (now.microsecondsSinceEpoch % 9000 + 1000).toString();
  return 'MED-$year$month$day-$seq';
}

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

// Realistic appointment payload for JSON encode/decode test
Map<String, dynamic> _buildAppointmentPayload(int index) => {
      'id': 'apt-${index.toString().padLeft(6, '0')}',
      'booking_code': 'EMR-1001-10000001',
      'patient_name': 'John Doe',
      'patient_phone': '+6281234567890',
      'doctor_name': 'Dr. Budi Santoso, Sp.PD',
      'clinic_name': 'Klinik Sehat Surabaya',
      'appointment_date': '2026-10-15',
      'appointment_time': '09:30',
      'status': 'confirmed',
      'notes': 'Kontrol rutin, bawa hasil lab terakhir.',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_first_visit': false,
      'queue_number': index % 50 + 1,
    };

void main() {
  const largeIterations = 10000;
  const medIterations = 1000;

  group('App core performance', () {
    // ── Booking code generation ─────────────────────────────────────────────
    test('appointmentBookingCode $largeIterations iterations', () {
      const appointmentId = 'apt-00000001';

      _benchmark('appointmentBookingCode', largeIterations, () {
        appointmentBookingCode(appointmentId);
      });

      final sw = Stopwatch()..start();
      for (var i = 0; i < largeIterations; i++) {
        appointmentBookingCode(appointmentId);
      }
      sw.stop();
      final avgMs = sw.elapsedMilliseconds / largeIterations;
      // Threshold: 0.5ms avg (pure integer arithmetic — should be << 0.1ms)
      expect(
        avgMs,
        lessThan(0.5),
        reason: 'appointmentBookingCode avg ${avgMs.toStringAsFixed(4)}ms exceeds 0.5ms',
      );
    });

    test('appointmentBookingCode correctness', () {
      final code = appointmentBookingCode('apt-00000001');
      expect(code, startsWith('EMR-'));
      // Deterministic for same input
      expect(appointmentBookingCode('apt-00000001'), code);
    });

    test('canonicalBookingCode — legacy upgrade $largeIterations iterations', () {
      _benchmark('canonicalBookingCode(legacy)', largeIterations, () {
        canonicalBookingCode(
          appointmentId: 'apt-00000001',
          storedCode: 'KDT-OLD-CODE',
        );
      });
    });

    test('canonicalBookingCode — stored code passthrough $largeIterations iterations', () {
      _benchmark('canonicalBookingCode(stored)', largeIterations, () {
        canonicalBookingCode(
          appointmentId: 'apt-00000001',
          storedCode: 'EMR-1001-10000001',
        );
      });
    });

    // ── Medical code generation ─────────────────────────────────────────────
    test('_generateMedicalCode $largeIterations iterations', () {
      _benchmark('_generateMedicalCode', largeIterations, _generateMedicalCode);

      final sw = Stopwatch()..start();
      for (var i = 0; i < largeIterations; i++) {
        _generateMedicalCode();
      }
      sw.stop();
      final avgMs = sw.elapsedMilliseconds / largeIterations;
      // Threshold: 0.5ms avg
      expect(
        avgMs,
        lessThan(0.5),
        reason: '_generateMedicalCode avg ${avgMs.toStringAsFixed(4)}ms exceeds 0.5ms',
      );

      // Correctness: must start with MED-
      expect(_generateMedicalCode(), startsWith('MED-'));
    });

    // ── Date formatting ─────────────────────────────────────────────────────
    test('DateTime.toIso8601String $largeIterations iterations', () {
      final now = DateTime.now();
      _benchmark('DateTime.toIso8601String', largeIterations, () {
        now.toIso8601String();
      });

      final sw = Stopwatch()..start();
      for (var i = 0; i < largeIterations; i++) {
        now.toIso8601String();
      }
      sw.stop();
      final avgMs = sw.elapsedMilliseconds / largeIterations;
      // Threshold: 1ms avg
      expect(
        avgMs,
        lessThan(1.0),
        reason: 'DateTime.toIso8601String avg ${avgMs.toStringAsFixed(4)}ms exceeds 1ms',
      );
    });

    test('DateTime toString formatting $largeIterations iterations', () {
      _benchmark('DateTime.toString', largeIterations, () {
        DateTime.now().toString();
      });
    });

    // ── JSON encode/decode ──────────────────────────────────────────────────
    test('JSON encode appointment payload $medIterations iterations', () {
      final payloads = List.generate(medIterations, _buildAppointmentPayload);

      _benchmark('jsonEncode(appointment)', medIterations, () {});
      final sw = Stopwatch()..start();
      for (var i = 0; i < medIterations; i++) {
        jsonEncode(payloads[i]);
      }
      sw.stop();
      final avgMs = sw.elapsedMilliseconds / medIterations;
      debugPrint(
        '[PERF] jsonEncode(appointment) ${medIterations}x: total=${sw.elapsedMilliseconds}ms avg=${avgMs.toStringAsFixed(4)}ms',
      );
      // Threshold: 5ms avg per encode
      expect(
        avgMs,
        lessThan(5.0),
        reason: 'jsonEncode avg ${avgMs.toStringAsFixed(4)}ms exceeds 5ms',
      );
    });

    test('JSON decode appointment payload $medIterations iterations', () {
      // Pre-encode to isolate decode timing
      final encoded = List.generate(
        medIterations,
        (i) => jsonEncode(_buildAppointmentPayload(i)),
      );

      final sw = Stopwatch()..start();
      for (var i = 0; i < medIterations; i++) {
        jsonDecode(encoded[i]);
      }
      sw.stop();
      final avgMs = sw.elapsedMilliseconds / medIterations;
      debugPrint(
        '[PERF] jsonDecode(appointment) ${medIterations}x: total=${sw.elapsedMilliseconds}ms avg=${avgMs.toStringAsFixed(4)}ms',
      );
      // Threshold: 5ms avg per decode
      expect(
        avgMs,
        lessThan(5.0),
        reason: 'jsonDecode avg ${avgMs.toStringAsFixed(4)}ms exceeds 5ms',
      );
    });
  });
}
