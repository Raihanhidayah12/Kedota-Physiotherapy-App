import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kedotaapp/utils/rest_crypto.dart';

void main() {
  setUpAll(() async {
    // Load test env with known keys
    dotenv.testLoad(fileInput: '''
REST_ENCRYPT_KEY=4b3c2d1e0f9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c
REST_HMAC_KEY=a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2
''');
  });

  group('RestCrypto', () {
    test('encryptPayload -> decryptPayload round trip', () {
      final original = {'pin': '123456', 'phone': '+6282310699436'};
      final encrypted = RestCrypto.encryptPayload(original);
      
      expect(encrypted['data'], isNotNull);
      expect(encrypted['iv'], isNotNull);
      expect(encrypted['sig'], isNotNull);
      expect(encrypted['data'], isNot(contains('123456')));
      
      final decrypted = RestCrypto.decryptPayload(encrypted);
      expect(decrypted['pin'], equals('123456'));
      expect(decrypted['phone'], equals('+6282310699436'));
    });

    test('encryptSensitiveFields encrypts only sensitive fields', () {
      final payload = {
        'patient_name': 'John',
        'phone': '+6282310699436',
        'pin_hash': 'abc123hash',
        'appointment_date': '2026-10-08',
      };
      final result = RestCrypto.encryptSensitiveFields(payload);
      
      expect(result['patient_name'], equals('John'));
      expect(result['appointment_date'], equals('2026-10-08'));
      expect(result['phone'], isA<Map>());
      expect(result['pin_hash'], isA<Map>());
    });

    test('tampered payload throws SecurityException', () {
      final original = {'data': 'test'};
      final encrypted = RestCrypto.encryptPayload(original);
      encrypted['data'] = 'TAMPERED_DATA';
      
      expect(
        () => RestCrypto.decryptPayload(encrypted),
        throwsA(isA<SecurityException>()),
      );
    });
  });
}
