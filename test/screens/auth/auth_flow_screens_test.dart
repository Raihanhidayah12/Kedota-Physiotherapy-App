import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kedotaapp/screens/auth/forgot_pin_screen.dart';
import 'package:kedotaapp/screens/auth/google_create_pin_screen.dart';
import 'package:kedotaapp/screens/auth/google_profile_completion_screen.dart';
import 'package:kedotaapp/screens/auth/phone_create_pin_screen.dart';
import 'package:kedotaapp/screens/auth/phone_profile_completion_screen.dart';
import 'package:kedotaapp/screens/auth/sign_in_screen.dart';
import 'package:kedotaapp/screens/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      publishableKey: 'dummy-anon-key',
    );
  });

  Widget host(Widget child) => MaterialApp(home: child);

  void useMobileViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Onboarding flow', () {
    testWidgets('renders the first page and skip action', (tester) async {
      await tester.pumpWidget(host(const OnboardingScreen()));
      await tester.pump();

      expect(find.text('Optimalkan Pemulihan Gerakmu'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('skip stores completion and opens sign in', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(host(const OnboardingScreen()));
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_seen_onboarding'), isTrue);
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  group('Forgot PIN flow', () {
    testWidgets('renders phone input and validates an empty phone', (
      tester,
    ) async {
      await tester.pumpWidget(host(const ForgotPinScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Masukkan No. Telepon'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.text('Kirim OTP'));
      await tester.pumpAndSettle();

      expect(find.text('Masukkan nomor telepon Anda'), findsOneWidget);
    });

    testWidgets('accepts the dummy OTP and calls verification callback', (
      tester,
    ) async {
      var verified = false;
      await tester.pumpWidget(
        host(
          ForgotPinOtpScreen(
            phoneNumber: '+6281234567890',
            onVerified: () => verified = true,
          ),
        ),
      );
      await tester.pump();

      final otpField = find.byType(TextField);
      expect(otpField, findsOneWidget);
      await tester.enterText(otpField, '1234');
      await tester.pump(const Duration(milliseconds: 400));

      expect(verified, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Phone and Google sign-up profile flow', () {
    testWidgets('phone profile screen renders required fields', (tester) async {
      await tester.pumpWidget(
        host(const PhoneProfileCompletionScreen(phoneNumber: '081234567890')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('Lengkapi Data Diri'), findsOneWidget);
    });

    testWidgets('Google profile screen renders prefilled account data', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const GoogleProfileCompletionScreen(
            email: 'user@example.com',
            initialFullName: 'Test User',
            initialPhone: '081234567890',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lengkapi Data Diri'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
    });

    testWidgets('phone create PIN screen renders the PIN keypad', (
      tester,
    ) async {
      useMobileViewport(tester);
      await tester.pumpWidget(
        host(
          PhoneCreatePinScreen(
            phone: '081234567890',
            fullName: 'Test User',
            email: 'user@example.com',
            birthDate: DateTime(1995, 1, 1),
            gender: 'male',
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.lock_person_outlined), findsOneWidget);
      expect(
        find.text(
          'Silakan buat 6 digit PIN Anda terlebih dahulu untuk melanjutkan.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Google create PIN screen renders the PIN keypad', (
      tester,
    ) async {
      useMobileViewport(tester);
      await tester.pumpWidget(
        host(
          GoogleCreatePinScreen(
            phone: '081234567890',
            fullName: 'Test User',
            email: 'user@example.com',
            birthDate: DateTime(1995, 1, 1),
            gender: 'Laki-Laki',
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.lock_person_outlined), findsOneWidget);
      expect(
        find.text(
          'Silakan buat 6 digit PIN Anda terlebih dahulu untuk melanjutkan.',
        ),
        findsOneWidget,
      );
    });
  });
}
