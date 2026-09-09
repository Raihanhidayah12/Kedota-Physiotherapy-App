// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:kedotaapp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'dummy-anon-key',
    );
  });

  testWidgets('Splash screen shows branding', (WidgetTester tester) async {
    await tester.pumpWidget(const KedotaApp());

    expect(find.text('Kedota'), findsOneWidget);
    expect(find.text('PHYSIOTHERAPY'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
