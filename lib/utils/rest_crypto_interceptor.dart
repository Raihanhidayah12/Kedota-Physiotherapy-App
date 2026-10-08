import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'rest_crypto.dart';

/// Dio interceptor that transparently encrypts request bodies
/// and decrypts response bodies for sensitive endpoints.
///
/// Only activates for endpoints that deal with sensitive data.
/// Supabase REST endpoints pass through normally (Supabase has its own security).
/// This interceptor is for custom API calls that need extra encryption.
class RestCryptoInterceptor extends Interceptor {
  /// Endpoints that should have payload encryption applied.
  /// Add paths here as needed.
  static const _encryptedPaths = <String>[
    '/functions/v1/update-pin',
    '/functions/v1/client-error-log',
  ];

  static bool _shouldEncrypt(String path) =>
      _encryptedPaths.any((p) => path.contains(p));

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      if (_shouldEncrypt(options.path) && options.data is Map) {
        final encrypted = RestCrypto.encryptPayload(
          Map<String, dynamic>.from(options.data as Map),
        );
        options.data = encrypted;
        options.headers['X-Encrypted'] = '1';
        options.headers['X-Encryption'] = 'AES-256-CBC';
        debugPrint('[RestCrypto] Request encrypted: ${options.path}');
      }
    } catch (e) {
      debugPrint('[RestCrypto] Encrypt error: $e');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    try {
      final isEncrypted = response.headers.value('X-Encrypted') == '1' ||
          (response.data is Map &&
              (response.data as Map).containsKey('data') &&
              (response.data as Map).containsKey('iv') &&
              (response.data as Map).containsKey('sig'));

      if (isEncrypted && response.data is Map) {
        final decrypted = RestCrypto.decryptPayload(
          Map<String, dynamic>.from(response.data as Map),
        );
        response.data = decrypted;
        debugPrint('[RestCrypto] Response decrypted: ${response.requestOptions.path}');
      }
    } catch (e) {
      debugPrint('[RestCrypto] Decrypt error: $e');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}
