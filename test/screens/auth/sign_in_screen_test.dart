import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kedotaapp/screens/auth/sign_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'dummy-anon-key',
    );
  });

  Widget createWidgetUnderTest() {
    return const MaterialApp(home: SignInScreen());
  }

  group('SignInScreen Widget Tests', () {
    testWidgets('Renders essential UI elements correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('K E D O T A'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('+62'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Masuk'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
    });

    testWidgets('Shows error when phone is empty and submit is pressed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Informasi'), findsOneWidget);
      expect(find.text('Masukkan nomor telepon Anda'), findsOneWidget);
    });
  });
}
