import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_language.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Could not load .env file: $e');
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ??
      const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://wwmctqhbqpsbkyxkeaqv.supabase.co',
      );

  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
      const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'sb_publishable_UgW9oHNC_Fzc7fUEFyecoQ_DUUqM25k',
      );

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E88E5),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
