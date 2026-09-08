import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_language.dart';
import 'services/notification_service.dart';
import 'screens/splash/splash_screen.dart';
import 'widgets/app_lock_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const KedotaApp());
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