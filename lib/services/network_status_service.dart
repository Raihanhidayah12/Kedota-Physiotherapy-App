import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NetworkStatusService {
  static final Connectivity _connectivity = Connectivity();
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
      sendTimeout: const Duration(seconds: 3),
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  static Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  static Future<bool> hasInternet() async {
    try {
      final connectionTypes = await _connectivity.checkConnectivity();
      if (connectionTypes.isNotEmpty &&
          connectionTypes.every((type) => type == ConnectivityResult.none)) {
        return false;
      }
    } catch (_) {
      // Still probe internet access if the platform connectivity plugin fails.
    }

    final baseUrl = (dotenv.env['SUPABASE_URL'] ?? '').trim();
    if (baseUrl.isEmpty) return true;

    try {
      final response = await _dio.get<dynamic>(
        '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/auth/v1/health',
      );
      return response.statusCode != null && response.statusCode! < 500;
    } catch (_) {
      return false;
    }
  }
}
