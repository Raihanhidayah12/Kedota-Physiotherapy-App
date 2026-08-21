import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kedotaapp/services/supabase_auth_service.dart';
import 'package:kedotaapp/services/supabase_api_client.dart';

// Anotasi ini akan memberitahu build_runner untuk membuat class MockSupabaseClient, dll.
@GenerateMocks([SupabaseClient, GoTrueClient, SupabaseApiClient])
void main() {
  late SupabaseAuthService authService;

  setUp(() {
    authService = SupabaseAuthService();
    // Catatan: Untuk men-test fungsi yang memanggil 'client' (seperti signIn, signUp),
    // kamu perlu me-refactor SupabaseAuthService agar menerima SupabaseClient via constructor 
    // atau menyediakan setter untuk me-replace '_client' dengan mock client.
    // Contoh refactor di SupabaseAuthService:
    // SupabaseAuthService({SupabaseClient? client}) : _client = client;
  });

  group('SupabaseAuthService - Pure Logic Tests', () {
    test('buildEmailFromPhone normalizes phone number', () {
      final email = authService.buildEmailFromPhone('+62 812-3456-7890');
      expect(email, '6281234567890@kedota.local');
    });

    test('resolveAuthEmail uses supplied email if valid', () {
      final email = authService.resolveAuthEmail('081234567890', suppliedEmail: 'test@example.com');
      expect(email, 'test@example.com');
    });

    test('resolveAuthEmail falls back to phone email if supplied email is invalid', () {
      final email = authService.resolveAuthEmail('081234567890', suppliedEmail: 'invalid-email');
      expect(email, '081234567890@kedota.local');
    });

    test('resolveAuthEmail falls back to phone email if supplied email is empty', () {
      final email = authService.resolveAuthEmail('081234567890');
      expect(email, '081234567890@kedota.local');
    });

    test('hashPin returns consistent SHA-256 hash', () {
      final hash1 = authService.hashPin('123456');
      final hash2 = authService.hashPin('123456');
      expect(hash1, hash2);
      // Validasi hash ini (bisa dicari online sha256 dari "123456")
      expect(hash1, '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92');
    });
  });
}
