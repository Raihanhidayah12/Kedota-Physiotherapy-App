import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_language.dart';
import 'services/client_error_log_service.dart';
import 'services/notification_service.dart';
import 'screens/splash/splash_screen.dart';
import 'widgets/app_lock_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Global Flutter / Dart error handlers ────────────────────────────────
  // These fire before runApp so they're always active, even during init.

  // 1. Framework errors (widget build failures, rendering, etc.)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // keeps default console output
    _reportUnhandledError(
      details.exception,
      details.stack,
      context: 'FlutterError.onError',
    );
  };

  // 2. Platform-level / isolate errors not caught by Flutter framework
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _reportUnhandledError(error, stack, context: 'PlatformDispatcher.onError');
    return true; // mark as handled — prevents crash on release builds
  };

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Could not load .env file: $e');
  }

  // Load bahasa tersimpan sebelum app jalan
  // Load saved language before app starts
  await loadSavedLanguage();

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

  // Inisialisasi sistem notifikasi
  await NotificationService().init();

  // 3. Uncaught async errors in the root zone
  runZonedGuarded(
    () => runApp(const KedotaApp()),
    (Object error, StackTrace stack) {
      _reportUnhandledError(error, stack, context: 'runZonedGuarded');
    },
  );
}

/// Inspect [error] and forward to [ClientErrorLogService] when it carries a
/// 5xx HTTP status code.  Never throws — logging must not crash the app.
void _reportUnhandledError(
  Object error,
  StackTrace? stack, {
  required String context,
}) {
  try {
    debugPrint('[$context] Unhandled error: $error');
    if (stack != null) debugPrint(stack.toString());

    const ClientErrorLogService().logIfUnknownServerError(
      error,
      method: 'UNKNOWN',
      path: context,
    );
  } catch (_) {
    // Swallow any logging failure — this is a last-resort handler.
  }
}

class KedotaApp extends StatelessWidget {
  const KedotaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLanguageScope(
      notifier: appLanguageNotifier,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Kedota Physiotherapy',
        navigatorKey: appNavigatorKey, // ← Key untuk push lock screen dari observer
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007F78),
            primary: const Color(0xFF007F78),
            secondary: const Color(0xFF00A79D),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.openSansTextTheme(),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: const Color(0xFF007F78),
            headerForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            dayStyle: const TextStyle(fontWeight: FontWeight.w600),
            yearStyle: const TextStyle(fontWeight: FontWeight.w600),
            cancelButtonStyle: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8AA8AC),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            confirmButtonStyle: TextButton.styleFrom(
              foregroundColor: const Color(0xFF007F78),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        home: AppLockWrapper(
          child: const SplashScreen(),
        ),
      ),
    );
  }
}