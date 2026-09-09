import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kedotaapp/main.dart';
import 'package:kedotaapp/screens/auth/sign_in_screen.dart';
import 'package:kedotaapp/screens/onboarding/onboarding_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  });

  group('End-to-End App Flow', () {
    testWidgets('App starts, shows splash, and navigates to Auth/Onboarding', (
      tester,
    ) async {
      await tester.pumpWidget(const KedotaApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Kedota'), findsOneWidget);
      expect(find.text('PHYSIOTHERAPY'), findsOneWidget);

      for (var attempt = 0; attempt < 12; attempt++) {
        final hasNavigated =
            find.byType(SignInScreen).evaluate().isNotEmpty ||
            find.byType(OnboardingScreen).evaluate().isNotEmpty;
        if (hasNavigated) break;
        await tester.pump(const Duration(milliseconds: 500));
      }

      final isAtSignIn = find.byType(SignInScreen).evaluate().isNotEmpty;
      final isAtOnboarding = find
          .byType(OnboardingScreen)
          .evaluate()
          .isNotEmpty;

      expect(
        isAtSignIn || isAtOnboarding,
        isTrue,
        reason:
            'Aplikasi tidak berpindah dari Splash Screen ke Sign In / Onboarding',
      );

      if (isAtSignIn) {
        final phoneField = find.byType(TextField);
        expect(phoneField, findsOneWidget);
        await tester.enterText(phoneField, '81234567890');
        expect(find.text('81234567890'), findsOneWidget);
      }
    });
  });
}
