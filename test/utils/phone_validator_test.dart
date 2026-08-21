import 'package:flutter_test/flutter_test.dart';
import 'package:kedotaapp/utils/phone_validator.dart';

void main() {
  group('PhoneValidator Tests', () {
    group('isValidIndonesianPhone', () {
      test('Returns true for valid 628... format', () {
        expect(PhoneValidator.isValidIndonesianPhone('6281234567890'), true);
      });

      test('Returns true for valid 08... format', () {
        expect(PhoneValidator.isValidIndonesianPhone('081234567890'), true);
      });

      test('Returns true for valid 8... format', () {
        expect(PhoneValidator.isValidIndonesianPhone('81234567890'), true);
      });

      test('Returns false for empty string', () {
        expect(PhoneValidator.isValidIndonesianPhone(''), false);
      });

      test('Returns false for invalid format (too short)', () {
        expect(PhoneValidator.isValidIndonesianPhone('0812'), false);
      });

      test('Returns false for non-Indonesian prefix', () {
        expect(PhoneValidator.isValidIndonesianPhone('12345678901'), false);
      });

      test('Ignores non-digit characters', () {
        expect(PhoneValidator.isValidIndonesianPhone('+62 812-3456-7890'), true);
      });
    });

    group('normalizePhoneNumber', () {
      test('Normalizes 62... format', () {
        expect(PhoneValidator.normalizePhoneNumber('6281234567890'), '+6281234567890');
      });

      test('Normalizes 08... format', () {
        expect(PhoneValidator.normalizePhoneNumber('081234567890'), '+6281234567890');
      });

      test('Normalizes 8... format', () {
        expect(PhoneValidator.normalizePhoneNumber('81234567890'), '+6281234567890');
      });

      test('Removes non-digit characters before normalizing', () {
        expect(PhoneValidator.normalizePhoneNumber('0812-3456-7890'), '+6281234567890');
        expect(PhoneValidator.normalizePhoneNumber('+62 812 3456 7890'), '+6281234567890');
      });
    });
  });
}
