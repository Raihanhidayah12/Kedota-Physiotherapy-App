import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// REST payload encryption/decryption using AES-256-CBC + HMAC-SHA256.
///
/// Usage:
/// ```dart
///   // Encrypt before sending
///   final payload = RestCrypto.encryptPayload({'pin': '123456', 'phone': '+62...'});
///
///   // Decrypt after receiving
///   final data = RestCrypto.decryptPayload(encryptedResponse);
/// ```
class RestCrypto {
  RestCrypto._();

  /// Encrypt a Map payload to a secure envelope:
  /// `{ "data": "base64-ciphertext", "iv": "base64-iv", "sig": "hmac-hex" }`
  static Map<String, dynamic> encryptPayload(Map<String, dynamic> plainPayload) {
    final key = _getAesKey();
    final hmacKey = _getHmacKey();
    
    // Generate random IV for each request
    final iv = enc.IV.fromSecureRandom(16);
    
    // Encrypt with AES-256-CBC
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final jsonStr = jsonEncode(plainPayload);
    final encrypted = encrypter.encrypt(jsonStr, iv: iv);
    
    final cipherB64 = encrypted.base64;
    final ivB64 = iv.base64;
    
    // Sign: HMAC-SHA256(iv + ciphertext)
    final sig = _hmacSign('$ivB64.$cipherB64', hmacKey);
    
    return {
      'data': cipherB64,
      'iv': ivB64,
      'sig': sig,
    };
  }

  /// Decrypt a secure envelope back to Map.
  /// Verifies HMAC signature before decrypting.
  static Map<String, dynamic> decryptPayload(Map<String, dynamic> envelope) {
    final key = _getAesKey();
    final hmacKey = _getHmacKey();
    
    final cipherB64 = envelope['data'] as String;
    final ivB64 = envelope['iv'] as String;
    final sig = envelope['sig'] as String;
    
    // Verify HMAC first
    final expectedSig = _hmacSign('$ivB64.$cipherB64', hmacKey);
    if (sig != expectedSig) {
      throw SecurityException('HMAC signature mismatch — payload may be tampered');
    }
    
    // Decrypt
    final iv = enc.IV.fromBase64(ivB64);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decrypt64(cipherB64, iv: iv);
    
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }

  /// Encrypt only specific sensitive fields in a payload (selective encryption).
  /// Non-sensitive fields pass through unencrypted.
  /// Sensitive fields: pin_hash, patient_nik, patient_phone, phone, pin
  static Map<String, dynamic> encryptSensitiveFields(Map<String, dynamic> payload) {
    const sensitiveFields = {
      'pin_hash', 'pin', 'patient_nik', 'patient_phone', 
      'phone', 'new_pin_hash', 'new_pin',
    };
    
    final result = Map<String, dynamic>.from(payload);
    final key = _getAesKey();
    final hmacKey = _getHmacKey();
    
    for (final field in sensitiveFields) {
      if (result.containsKey(field) && result[field] != null) {
        final iv = enc.IV.fromSecureRandom(16);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        final encrypted = encrypter.encrypt(result[field].toString(), iv: iv);
        final cipherB64 = encrypted.base64;
        final ivB64 = iv.base64;
        final sig = _hmacSign('$ivB64.$cipherB64', hmacKey);
        // Replace field with encrypted envelope
        result[field] = {'_enc': cipherB64, '_iv': ivB64, '_sig': sig};
      }
    }
    return result;
  }

  /// Decrypt selective-encrypted fields.
  static Map<String, dynamic> decryptSensitiveFields(Map<String, dynamic> payload) {
    final result = Map<String, dynamic>.from(payload);
    final key = _getAesKey();
    final hmacKey = _getHmacKey();
    
    for (final entry in result.entries.toList()) {
      final val = entry.value;
      if (val is Map && val.containsKey('_enc')) {
        final cipherB64 = val['_enc'] as String;
        final ivB64 = val['_iv'] as String;
        final sig = val['_sig'] as String;
        final expectedSig = _hmacSign('$ivB64.$cipherB64', hmacKey);
        if (sig != expectedSig) {
          throw SecurityException('HMAC mismatch for field ${entry.key}');
        }
        final iv = enc.IV.fromBase64(ivB64);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        result[entry.key] = encrypter.decrypt64(cipherB64, iv: iv);
      }
    }
    return result;
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static enc.Key _getAesKey() {
    final keyHex = dotenv.env['REST_ENCRYPT_KEY'] ?? '';
    if (keyHex.isEmpty) throw StateError('REST_ENCRYPT_KEY not set in .env');
    final bytes = _hexToBytes(keyHex);
    return enc.Key(Uint8List.fromList(bytes));
  }

  static List<int> _getHmacKey() {
    final keyHex = dotenv.env['REST_HMAC_KEY'] ?? '';
    if (keyHex.isEmpty) throw StateError('REST_HMAC_KEY not set in .env');
    return _hexToBytes(keyHex);
  }

  static String _hmacSign(String data, List<int> key) {
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
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
