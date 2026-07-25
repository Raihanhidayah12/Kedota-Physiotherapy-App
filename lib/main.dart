import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_language.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wwmctqhbqpsbkyxkeaqv.supabase.co',
    publishableKey: 'sb_publishable_UgW9oHNC_Fzc7fUEFyecoQ_DUUqM25k',
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
