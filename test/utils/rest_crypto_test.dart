import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kedotaapp/utils/rest_crypto.dart';

// ── Dedicated test keys — NOT the production keys from .env ──────────────────
// These are synthetic keys used only for unit tests.
// Production keys live in .env and must never appear in source control.
const _testEncryptKey =
    'deadbeefcafebabe0123456789abcdef0123456789abcdef0123456789abcdef';  // 64 hex
const _testHmacKey =
    'feedfacedeadbeefcafebabefeedface0123456789abcdef0123456789abcdef01'; // 66 hex (≥64)

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
REST_ENCRYPT_KEY=$_testEncryptKey
REST_HMAC_KEY=$_testHmacKey
''');
  });

  group('RestCrypto — full envelope', () {
    test('encryptPayload / decryptPayload round-trip', () {
      final original = {'pin': '123456', 'phone': '+6282310699436'};
      final encrypted = RestCrypto.encryptPayload(original);

      // Envelope fields exist
      expect(encrypted['data'], isA<String>());
      expect(encrypted['iv'],   isA<String>());
      expect(encrypted['sig'],  isA<String>());

      // Plaintext is NOT visible in ciphertext
      expect(encrypted['data'], isNot(contains('123456')));
      expect(encrypted['data'], isNot(contains('+6282310699436')));

      // Round-trip produces identical data
      final decrypted = RestCrypto.decryptPayload(encrypted);
      expect(decrypted['pin'],   equals('123456'));
      expect(decrypted['phone'], equals('+6282310699436'));
    });

    test('each encryption produces a different ciphertext (random IV)', () {
      final payload = {'value': 'same'};
      final enc1 = RestCrypto.encryptPayload(payload);
      final enc2 = RestCrypto.encryptPayload(payload);
      expect(enc1['data'], isNot(equals(enc2['data'])));
      expect(enc1['iv'],   isNot(equals(enc2['iv'])));
    });

    test('tampered data field throws SecurityException', () {
      final encrypted = RestCrypto.encryptPayload({'x': 1});
      encrypted['data'] = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
      expect(
        () => RestCrypto.decryptPayload(encrypted),
        throwsA(isA<SecurityException>()),
      );
    });

    test('tampered iv field throws SecurityException', () {
      final encrypted = RestCrypto.encryptPayload({'x': 1});
      encrypted['iv'] = 'AAAAAAAAAAAAAAAAAAAAAA==';
      expect(
        () => RestCrypto.decryptPayload(encrypted),
        throwsA(isA<SecurityException>()),
      );
    });

    test('tampered sig field throws SecurityException', () {
      final encrypted = RestCrypto.encryptPayload({'x': 1});
      encrypted['sig'] = '0' * 64;
      expect(
        () => RestCrypto.decryptPayload(encrypted),
        throwsA(isA<SecurityException>()),
      );
    });
  });

  group('RestCrypto — selective field encryption', () {
    test('only sensitive fields are encrypted', () {
      final payload = {
        'patient_name':     'John',         // NOT sensitive
        'appointment_date': '2026-10-08',   // NOT sensitive
        'phone':            '+6282310699436', // sensitive
        'pin_hash':         'abc123hash',    // sensitive
      };
      final result = RestCrypto.encryptSensitiveFields(payload);

      // Non-sensitive pass through unchanged
      expect(result['patient_name'],     equals('John'));
      expect(result['appointment_date'], equals('2026-10-08'));

      // Sensitive fields are replaced with envelope maps
      expect(result['phone'],    isA<Map>());
      expect(result['pin_hash'], isA<Map>());

      // Envelope contains the required keys
      final phoneEnv = result['phone'] as Map;
      expect(phoneEnv.containsKey('_enc'), isTrue);
      expect(phoneEnv.containsKey('_iv'),  isTrue);
      expect(phoneEnv.containsKey('_sig'), isTrue);
    });

    test('selective encrypt / decrypt round-trip', () {
      final payload = {
        'label': 'keep-me',
        'pin':   'secret-pin',
        'phone': '+6281234567890',
      };
      final encrypted = RestCrypto.encryptSensitiveFields(payload);
      final decrypted = RestCrypto.decryptSensitiveFields(encrypted);

      expect(decrypted['label'], equals('keep-me'));
      expect(decrypted['pin'],   equals('secret-pin'));
      expect(decrypted['phone'], equals('+6281234567890'));
    });

    test('tampered selective field throws SecurityException', () {
      final encrypted = RestCrypto.encryptSensitiveFields({'pin': 'secret'});
      // Corrupt the ciphertext of the pin envelope
      (encrypted['pin'] as Map)['_enc'] = 'TAMPERED==';
      expect(
        () => RestCrypto.decryptSensitiveFields(encrypted),
        throwsA(isA<SecurityException>()),
      );
    });
  });

  group('RestCrypto — key validation', () {
    test('short AES key throws StateError', () {
      dotenv.testLoad(fileInput: '''
REST_ENCRYPT_KEY=tooshort
REST_HMAC_KEY=$_testHmacKey
''');
      expect(
        () => RestCrypto.encryptPayload({'x': 1}),
        throwsA(isA<StateError>()),
      );
      // Restore valid keys for subsequent tests
      dotenv.testLoad(fileInput: '''
REST_ENCRYPT_KEY=$_testEncryptKey
REST_HMAC_KEY=$_testHmacKey
''');
    });

    test('empty HMAC key throws StateError', () {
      dotenv.testLoad(fileInput: '''
REST_ENCRYPT_KEY=$_testEncryptKey
REST_HMAC_KEY=
''');
      expect(
        () => RestCrypto.encryptPayload({'x': 1}),
        throwsA(isA<StateError>()),
      );
      // Restore
      dotenv.testLoad(fileInput: '''
REST_ENCRYPT_KEY=$_testEncryptKey
REST_HMAC_KEY=$_testHmacKey
''');
    });
  });
}
