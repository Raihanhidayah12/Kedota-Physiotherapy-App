import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// REST payload encryption/decryption using AES-256-CBC + HMAC-SHA256.
///
/// Provides two modes:
/// 1. Full envelope encryption  — [encryptPayload] / [decryptPayload]
/// 2. Selective field encryption — [encryptSensitiveFields] / [decryptSensitiveFields]
///
/// Keys are loaded from `.env`:
///   REST_ENCRYPT_KEY  — 64 hex chars (32 bytes) for AES-256
///   REST_HMAC_KEY     — 64 hex chars (32 bytes) for HMAC-SHA256
class RestCrypto {
  RestCrypto._();

  /// Sensitive field names that get encrypted in selective mode.
  static const sensitiveFields = {
    'pin_hash', 'pin', 'patient_nik', 'patient_phone',
    'phone', 'new_pin_hash', 'new_pin',
  };

  // ── Full envelope encrypt/decrypt ────────────────────────────────────────

  /// Encrypt [plainPayload] to a signed envelope:
  /// `{ "data": "<b64>", "iv": "<b64>", "sig": "<hex>" }`
  static Map<String, dynamic> encryptPayload(Map<String, dynamic> plainPayload) {
    final key     = _getAesKey();
    final hmacKey = _getHmacKey();
    final iv      = enc.IV.fromSecureRandom(16);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final cipherB64 = encrypter.encrypt(jsonEncode(plainPayload), iv: iv).base64;
    final ivB64     = iv.base64;
    final sig       = _hmacSign('$ivB64.$cipherB64', hmacKey);

    return {'data': cipherB64, 'iv': ivB64, 'sig': sig};
  }

  /// Verify HMAC then decrypt [envelope] back to a Map.
  /// Throws [SecurityException] if the signature is invalid.
  static Map<String, dynamic> decryptPayload(Map<String, dynamic> envelope) {
    final key     = _getAesKey();
    final hmacKey = _getHmacKey();

    final cipherB64 = envelope['data'] as String;
    final ivB64     = envelope['iv']   as String;
    final sig       = envelope['sig']  as String;

    // Constant-time HMAC verification — prevents timing attacks
    final expectedSig = _hmacSign('$ivB64.$cipherB64', hmacKey);
    if (!_constantTimeEquals(sig, expectedSig)) {
      throw SecurityException(
        'HMAC signature mismatch — payload may be tampered',
      );
    }

    final iv        = enc.IV.fromBase64(ivB64);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return jsonDecode(encrypter.decrypt64(cipherB64, iv: iv))
        as Map<String, dynamic>;
  }

  // ── Selective field encrypt/decrypt ──────────────────────────────────────

  /// Encrypt only [sensitiveFields] in [payload]; other fields pass through.
  static Map<String, dynamic> encryptSensitiveFields(
    Map<String, dynamic> payload,
  ) {
    final key     = _getAesKey();
    final hmacKey = _getHmacKey();
    final result  = Map<String, dynamic>.from(payload);

    for (final field in sensitiveFields) {
      if (result.containsKey(field) && result[field] != null) {
        final iv        = enc.IV.fromSecureRandom(16);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        final cipherB64 = encrypter.encrypt(result[field].toString(), iv: iv).base64;
        final ivB64     = iv.base64;
        final sig       = _hmacSign('$ivB64.$cipherB64', hmacKey);
        result[field]   = {'_enc': cipherB64, '_iv': ivB64, '_sig': sig};
      }
    }
    return result;
  }

  /// Decrypt fields that were encrypted by [encryptSensitiveFields].
  /// Throws [SecurityException] on HMAC mismatch for any field.
  static Map<String, dynamic> decryptSensitiveFields(
    Map<String, dynamic> payload,
  ) {
    final key     = _getAesKey();
    final hmacKey = _getHmacKey();
    final result  = Map<String, dynamic>.from(payload);

    for (final entry in result.entries.toList()) {
      final val = entry.value;
      if (val is Map && val.containsKey('_enc')) {
        final cipherB64 = val['_enc'] as String;
        final ivB64     = val['_iv']  as String;
        final sig       = val['_sig'] as String;

        // Constant-time HMAC check
        final expectedSig = _hmacSign('$ivB64.$cipherB64', hmacKey);
        if (!_constantTimeEquals(sig, expectedSig)) {
          throw SecurityException(
            'HMAC mismatch for field "${entry.key}" — payload may be tampered',
          );
        }

        final iv        = enc.IV.fromBase64(ivB64);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        result[entry.key] = encrypter.decrypt64(cipherB64, iv: iv);
      }
    }
    return result;
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static enc.Key _getAesKey() {
    final hex = dotenv.env['REST_ENCRYPT_KEY'] ?? '';
    if (hex.isEmpty) throw StateError('REST_ENCRYPT_KEY not set in .env');
    // AES-256 requires exactly 32 bytes = 64 hex chars
    if (hex.length != 64) {
      throw StateError(
        'REST_ENCRYPT_KEY must be 64 hex characters (32 bytes); '
        'got ${hex.length}',
      );
    }
    return enc.Key(Uint8List.fromList(_hexToBytes(hex)));
  }

  static List<int> _getHmacKey() {
    final hex = dotenv.env['REST_HMAC_KEY'] ?? '';
    if (hex.isEmpty) throw StateError('REST_HMAC_KEY not set in .env');
    // HMAC-SHA256 key should be at least 32 bytes = 64 hex chars
    if (hex.length < 64) {
      throw StateError(
        'REST_HMAC_KEY must be at least 64 hex characters (32 bytes); '
        'got ${hex.length}',
      );
    }
    return _hexToBytes(hex);
  }

  static String _hmacSign(String data, List<int> key) {
    return Hmac(sha256, key).convert(utf8.encode(data)).toString();
  }

  /// Constant-time string comparison — prevents timing side-channel attacks.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}

class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);
  @override
  String toString() => 'SecurityException: $message';
}
