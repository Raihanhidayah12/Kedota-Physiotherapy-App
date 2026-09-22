import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientErrorLogService {
  const ClientErrorLogService();

  // ---------------------------------------------------------------------------
  // Core send method — used by the Dio interceptor and all Supabase-client
  // call sites that detect a 5xx condition.
  // ---------------------------------------------------------------------------

  Future<void> sendServerError({
    required String method,
    required String path,
    required int statusCode,
    String? message,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'client-error-log',
        body: {
          'source': 'flutter_client',
          'method': method,
          'path': path,
          'status_code': statusCode,
          if (message != null && message.isNotEmpty) 'message': message,
          'platform': defaultTargetPlatform.name,
        },
      );
    } catch (error) {
      debugPrint('Client 5xx log upload failed: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // Supabase-client helpers
  // ---------------------------------------------------------------------------

  /// Inspect an [AuthException] and fire a 5xx log when its HTTP status is
  /// in the 500–599 range.  Returns true if a log was sent.
  bool logIfAuthServerError(
    AuthException error, {
    required String operation,
  }) {
    final code = int.tryParse(error.statusCode ?? '');
    if (code != null && code >= 500 && code <= 599) {
      debugPrint('Supabase auth 5xx: $code $operation – ${error.message}');
      _sendFireAndForget(
        method: 'POST',
        path: '/auth/v1/$operation',
        statusCode: code,
        message: error.message,
      );
      return true;
    }
    return false;
  }

  /// Inspect a [PostgrestException] (raised by `.from()`, `.rpc()`, `.storage`)
  /// and fire a 5xx log when its HTTP status is 500–599.  Returns true if a
  /// log was sent.
  bool logIfPostgrestServerError(
    PostgrestException error, {
    required String method,
    required String path,
  }) {
    final code = error.code != null ? int.tryParse(error.code!) : null;
    // PostgrestException.code is the Postgres error code (e.g. "23505"), NOT
    // the HTTP status code.  The HTTP status lives in error.details or the
    // message prefix.  We check the details field as a fallback.
    final httpCode = _extractHttpStatus(error.message) ??
        _extractHttpStatus(error.details?.toString() ?? '') ??
        code;

    if (httpCode != null && httpCode >= 500 && httpCode <= 599) {
      debugPrint('Supabase postgrest 5xx: $httpCode $method $path – ${error.message}');
      _sendFireAndForget(
        method: method,
        path: path,
        statusCode: httpCode,
        message: error.message,
      );
      return true;
    }
    return false;
  }

  /// Generic catcher for unknown errors that may wrap a 5xx HTTP response.
  /// Parses the stringified error for an HTTP status in the 500–599 range.
  bool logIfUnknownServerError(
    Object error, {
    required String method,
    required String path,
  }) {
    final code = _extractHttpStatus(error.toString());
    if (code != null && code >= 500 && code <= 599) {
      debugPrint('Supabase unknown 5xx: $code $method $path – $error');
      _sendFireAndForget(
        method: method,
        path: path,
        statusCode: code,
        message: error.toString(),
      );
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _sendFireAndForget({
    required String method,
    required String path,
    required int statusCode,
    String? message,
  }) {
    // Deliberately unawaited — logging must never block business logic.
    sendServerError(
      method: method,
      path: path,
      statusCode: statusCode,
      message: message,
    ).ignore();
  }

  /// Extract the first 3-digit HTTP status code (500–599) found in [text].
  int? _extractHttpStatus(String text) {
    final match = RegExp(r'\b(5\d{2})\b').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
