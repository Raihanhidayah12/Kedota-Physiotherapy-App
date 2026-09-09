import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientErrorLogService {
  const ClientErrorLogService();

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
}
