import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppNetworkStatus {
  online,
  noInternet,
  serverDown,
}

class NetworkStatusService {
  static final Connectivity _connectivity = Connectivity();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      sendTimeout: const Duration(seconds: 4),
      validateStatus: (status) => status != null,
    ),
  );

  static final ValueNotifier<AppNetworkStatus> statusNotifier =
      ValueNotifier<AppNetworkStatus>(AppNetworkStatus.online);

  static Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// Laporkan secara eksplisit jika terjadi server error (misal 5xx dari API).
  static void reportServerDown() {
    if (statusNotifier.value != AppNetworkStatus.serverDown) {
      statusNotifier.value = AppNetworkStatus.serverDown;
    }
  }

  /// Cek koneksi internet publik secara independen untuk membedakan
  /// antara jaringan lokal user yang mati vs backend server yang sedang down.
  static Future<bool> _probePublicInternet() async {
    try {
      final response = await _dio.get<dynamic>(
        'https://clients3.google.com/generate_204',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status == 204 || status == 200,
        ),
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      try {
        final fallback = await _dio.get<dynamic>(
          'https://1.1.1.1',
          options: Options(
            responseType: ResponseType.plain,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        return fallback.statusCode != null && fallback.statusCode! < 500;
      } catch (_) {
        return false;
      }
    }
  }

  /// Memeriksa status kesehatan jaringan dan server secara komprehensif.
  static Future<AppNetworkStatus> checkStatus() async {
    try {
      final connectionTypes = await _connectivity.checkConnectivity();
      if (connectionTypes.isNotEmpty &&
          connectionTypes.every((type) => type == ConnectivityResult.none)) {
        statusNotifier.value = AppNetworkStatus.noInternet;
        return AppNetworkStatus.noInternet;
      }
    } catch (_) {
      // Abaikan jika plugin platform connectivity bermasalah, lanjutkan probe HTTP
    }

    final baseUrl = (dotenv.env['SUPABASE_URL'] ?? '').trim();
    if (baseUrl.isEmpty) {
      statusNotifier.value = AppNetworkStatus.online;
      return AppNetworkStatus.online;
    }

    try {
      final anonKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();
      final response = await _dio.get<dynamic>(
        '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/auth/v1/health',
        options: Options(
          headers: {
            if (anonKey.isNotEmpty) 'apikey': anonKey,
            if (anonKey.isNotEmpty) 'Authorization': 'Bearer $anonKey',
          },
        ),
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 500) {
        // Server Supabase merespons dengan HTTP 5xx -> Server Down
        statusNotifier.value = AppNetworkStatus.serverDown;
        return AppNetworkStatus.serverDown;
      }

      // Supabase sehat dan merespons normal
      statusNotifier.value = AppNetworkStatus.online;
      return AppNetworkStatus.online;
    } catch (_) {
      // Supabase tidak merespons (Connection refused, timeout, host lookup failed).
      // Periksa apakah internet publik user aktif:
      final hasPublicInternet = await _probePublicInternet();
      if (hasPublicInternet) {
        // User memiliki internet, namun Supabase tidak dapat dijangkau -> Server Down
        statusNotifier.value = AppNetworkStatus.serverDown;
        return AppNetworkStatus.serverDown;
      } else {
        // User tidak memiliki akses internet sama sekali -> No Internet
        statusNotifier.value = AppNetworkStatus.noInternet;
        return AppNetworkStatus.noInternet;
      }
    }
  }

  /// Backward-compatible wrapper
  static Future<bool> hasInternet() async {
    final status = await checkStatus();
    return status == AppNetworkStatus.online;
  }
}
