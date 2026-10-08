import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'rest_crypto.dart';

/// Dio interceptor that transparently encrypts outgoing request bodies
/// and decrypts incoming response bodies for configured sensitive endpoints.
///
/// If [SecurityException] is thrown during decrypt (tamper detected), the
/// response is **rejected** as a [DioException] rather than silently passed
/// through — ensuring tamper detection is never neutralised.
class RestCryptoInterceptor extends Interceptor {
  /// Endpoints that require payload encryption.
  static const _encryptedPaths = <String>[
    '/functions/v1/update-pin',
    '/functions/v1/client-error-log',
  ];

  static bool _shouldEncrypt(String path) =>
      _encryptedPaths.any((p) => path.contains(p));

  // ── Outgoing request — encrypt ───────────────────────────────────────────

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (_shouldEncrypt(options.path) && options.data is Map) {
      try {
        final encrypted = RestCrypto.encryptPayload(
          Map<String, dynamic>.from(options.data as Map),
        );
        options.data = encrypted;
        options.headers['X-Encrypted']  = '1';
        options.headers['X-Encryption'] = 'AES-256-CBC';
        debugPrint('[RestCrypto] ✅ Request encrypted: ${options.path}');
      } catch (e) {
        // Encryption failure → reject the request, do NOT send plain-text
        debugPrint('[RestCrypto] ❌ Encrypt error, rejecting request: $e');
        handler.reject(
          DioException(
            requestOptions: options,
            error: 'RestCrypto: failed to encrypt request — $e',
            type: DioExceptionType.unknown,
          ),
          true,
        );
        return;
      }
    }
    handler.next(options);
  }

  // ── Incoming response — decrypt ──────────────────────────────────────────

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final isEncryptedResponse =
        response.headers.value('X-Encrypted') == '1' ||
        (response.data is Map &&
            (response.data as Map).containsKey('data') &&
            (response.data as Map).containsKey('iv') &&
            (response.data as Map).containsKey('sig'));

    if (isEncryptedResponse && response.data is Map) {
      try {
        final decrypted = RestCrypto.decryptPayload(
          Map<String, dynamic>.from(response.data as Map),
        );
        response.data = decrypted;
        debugPrint(
          '[RestCrypto] ✅ Response decrypted: ${response.requestOptions.path}',
        );
      } on SecurityException catch (e) {
        // Tamper detected → reject response, do NOT deliver tampered data
        debugPrint('[RestCrypto] 🚨 Tamper detected, rejecting response: $e');
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            error: e.toString(),
            type: DioExceptionType.badResponse,
          ),
          true,
        );
        return;
      } catch (e) {
        // Unexpected decrypt failure → also reject
        debugPrint('[RestCrypto] ❌ Decrypt error, rejecting response: $e');
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            error: 'RestCrypto: failed to decrypt response — $e',
            type: DioExceptionType.unknown,
          ),
          true,
        );
        return;
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}
