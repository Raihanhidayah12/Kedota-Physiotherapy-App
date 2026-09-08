import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mengontrol FLAG_SECURE per-screen.
/// - [enable]: konten disembunyikan di recent apps + screenshot diblokir
/// - [disable]: screenshot dan recent apps kembali normal
///
/// Hanya bekerja di Android. iOS/web diabaikan secara otomatis.
class ScreenSecurityService {
  static const _channel = MethodChannel('com.example.kedotaapp/screen_security');

  static Future<void> enable() async {
    if (kIsWeb || !_isAndroid) return;
    try {
      await _channel.invokeMethod('enableSecure');
    } catch (_) {}
  }

  static Future<void> disable() async {
    if (kIsWeb || !_isAndroid) return;
    try {
      await _channel.invokeMethod('disableSecure');
    } catch (_) {}
  }

  static bool get _isAndroid {
    try {
      return defaultTargetPlatform == TargetPlatform.android;
    } catch (_) {
      return false;
    }
  }
}

/// Mixin untuk State yang butuh screen security.
/// Otomatis enable saat initState dan disable saat dispose.
///
/// Penggunaan:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with SecureScreenMixin {
///   ...
/// }
/// ```
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    ScreenSecurityService.enable();
  }

  @override
  void dispose() {
    ScreenSecurityService.disable();
    super.dispose();
  }
}
