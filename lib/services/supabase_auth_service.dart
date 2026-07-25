import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'supabase_api_client.dart';

String get _supabasePublishableKey =>
    dotenv.env['SUPABASE_ANON_KEY'] ??
    const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_UgW9oHNC_Fzc7fUEFyecoQ_DUUqM25k',
    );

class SupabaseAuthService {
  SupabaseClient? _client;

  SupabaseClient get client {
    if (_client != null) {
      return _client!;
    }

    try {
      return _client = Supabase.instance.client;
    } catch (_) {
      throw Exception('Supabase is not initialized.');
    }
  }

  SupabaseApiClient get apiClient {
    final dio = Dio();
    dio.options.headers['apikey'] = _supabasePublishableKey;
    dio.options.headers['Content-Type'] = 'application/json';
    return SupabaseApiClient(dio);
  }

  String buildEmailFromPhone(String phone) {
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    return '$normalized@kedota.local';
  }

  String resolveAuthEmail(String phone, {String? suppliedEmail}) {
    final trimmedEmail = suppliedEmail?.trim() ?? '';
    if (trimmedEmail.isNotEmpty &&
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmedEmail)) {
      return trimmedEmail;
    }
    return buildEmailFromPhone(phone);
  }

  String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  String _formatSupabaseError(Object error) {
    if (error is AuthException) {
      return error.message;
    }

    final message = error.toString();
    if (message.contains('Database error saving new user')) {
      return 'Supabase rejected the sign-up request because the project auth database could not create the user. Please verify the Supabase project/auth configuration.';
    }

    return message;
  }

  Future<String> _resolveAccessToken({String? email, String? password}) async {
    final session = client.auth.currentSession;
    if (session?.accessToken != null && session!.accessToken.isNotEmpty) {
      return session.accessToken;
    }

    if (email != null && password != null) {
      final signInResponse = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return signInResponse.session?.accessToken ?? '';
    }

    return '';
  }

  Future<void> _persistProfile({
    required String userId,
    required Map<String, dynamic> profileData,
    bool isUpdate = false,
    String? email,
    String? password,
  }) async {
    final accessToken = await _resolveAccessToken(
      email: email,
      password: password,
    );

    try {
      if (isUpdate) {
        await apiClient.updateProfile(
          id: userId,
          apiKey: _supabasePublishableKey,
          authorization: accessToken.isNotEmpty
              ? 'Bearer $accessToken'
              : 'Bearer $_supabasePublishableKey',
          body: profileData,
        );
      } else {
        await apiClient.createProfile(
          apiKey: _supabasePublishableKey,
          authorization: accessToken.isNotEmpty
              ? 'Bearer $accessToken'
              : 'Bearer $_supabasePublishableKey',
          body: profileData,
        );
      }
    } on DioException catch (error, stackTrace) {
      debugPrint('Retrofit profile request failed: $error');
      debugPrint(stackTrace.toString());
      throw Exception('Unable to sync profile to Supabase.');
    } catch (error, stackTrace) {
      debugPrint('Unexpected profile request error: $error');
      debugPrint(stackTrace.toString());
      throw Exception('Unable to sync profile to Supabase.');
    }
  }

  Future<AuthResult> signUpWithPhone({
    required String phone,
    required String pin,
    required String fullName,
    required String email,
    required DateTime birthDate,
    required String gender,
  }) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');
    final authEmail = resolveAuthEmail(phone, suppliedEmail: email);

    try {
      final response = await client.auth.signUp(
        email: authEmail,
        password: pin,
        data: {
          'phone': normalizedPhone,
          'full_name': fullName,
          'signup_method': 'phone',
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Unable to create Supabase account.');
      }

      await _persistProfile(
        userId: user.id,
        email: authEmail,
        password: pin,
        profileData: {
          'id': user.id,
          'phone': normalizedPhone,
          'full_name': fullName,
          'email': email.isNotEmpty ? email : authEmail,
          'birth_date': birthDate.toIso8601String().split('T').first,
          'gender': gender,
          'signup_method': 'phone',
          'pin_hash': hashPin(pin),
          'is_profile_complete': true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      return AuthResult(userId: user.id, email: authEmail, supabaseUser: user);
    } catch (error, stackTrace) {
      debugPrint('Supabase signUp failed: $error');
      debugPrint(stackTrace.toString());
      throw Exception(_formatSupabaseError(error));
    }
  }

  Future<AuthResult> signInWithPhone({
    required String phone,
    required String pin,
  }) async {
    try {
      final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');
      
      // Look up the email associated with this phone number
      final profile = await client
          .from('profiles')
          .select('email')
          .eq('phone', normalizedPhone)
          .maybeSingle();

      if (profile == null || profile['email'] == null) {
        throw Exception('phoneNotRegisteredOrIncomplete');
      }

      final email = profile['email'] as String;

      final response = await client.auth.signInWithPassword(
        email: email,
        password: pin,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Invalid phone or PIN.');
      }

      await _persistProfile(
        userId: user.id,
        email: email,
        password: pin,
        isUpdate: true,
        profileData: {
          'last_login_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      return AuthResult(
        userId: user.id,
        email: email,
        supabaseUser: user,
      );
    } catch (error, stackTrace) {
      debugPrint('Supabase signIn failed: $error');
      debugPrint(stackTrace.toString());
      throw Exception(_formatSupabaseError(error));
    }
  }

  Future<void> signInWithGoogle({String? redirectTo}) async {
    try {
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          const webClientId = '1070539718443-c8ukpkb6cde0h401nkc0j7v1g03err91.apps.googleusercontent.com';
          final googleSignIn = GoogleSignIn(
            serverClientId: webClientId,
          );
          final googleUser = await googleSignIn.signIn();
          if (googleUser == null) {
            // User cancelled native picker
            return;
          }

          final googleAuth = await googleUser.authentication;
          final idToken = googleAuth.idToken;
          final accessToken = googleAuth.accessToken;

          if (idToken != null) {
            await client.auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: idToken,
              accessToken: accessToken,
            );
            return;
          }
        } catch (nativeError) {
          debugPrint('Native Google Sign-In failed, falling back to OAuth Web: $nativeError');
        }
      }

      // Web or fallback platform OAuth flow
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
    } catch (error, stackTrace) {
      debugPrint('Supabase Google signIn failed: $error');
      debugPrint(stackTrace.toString());
      throw Exception(_formatSupabaseError(error));
    }
  }

  Future<AuthResult> completeSocialProfile({
    required String phone,
    required String pin,
    required String fullName,
    required String email,
    required DateTime birthDate,
    required String gender,
    required String provider,
  }) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('No active social session found.');
      }

      final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');

      // Attempt to update the user's password if allowed for this provider session
      try {
        await client.auth.updateUser(
          UserAttributes(password: pin),
        );
      } catch (authErr) {
        debugPrint('Notice: Auth password update optional for social session: $authErr');
      }

      final profilePayload = {
        'id': user.id,
        'phone': normalizedPhone,
        'full_name': fullName,
        'email': user.email ?? email,
        'birth_date': birthDate.toIso8601String().split('T').first,
        'gender': gender,
        'signup_method': provider,
        'pin_hash': hashPin(pin),
        'is_profile_complete': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      try {
        await client.from('profiles').upsert(profilePayload);
      } catch (upsertErr) {
        debugPrint('Upsert error, falling back to _persistProfile: $upsertErr');
        await _persistProfile(
          userId: user.id,
          email: user.email ?? email,
          password: pin,
          isUpdate: true,
          profileData: profilePayload,
        );
      }

      return AuthResult(userId: user.id, email: user.email ?? email, supabaseUser: user);
    } catch (error, stackTrace) {
      debugPrint('Supabase completeSocialProfile failed: $error');
      debugPrint(stackTrace.toString());
      throw Exception(_formatSupabaseError(error));
    }
  }

  Future<Map<String, dynamic>?> checkUserProfileExists() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        return null;
      }

      final response = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return response;
    } catch (error, stackTrace) {
      debugPrint('Error checking profile existence: $error');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  List<String> _getPhoneFilterVariants(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return [];

    String base = digits;
    if (digits.startsWith('62')) {
      base = digits.substring(2);
    } else if (digits.startsWith('0')) {
      base = digits.substring(1);
    }

    final list = [
      '62$base',
      '+62$base',
      '0$base',
      digits,
    ];
    return list.toSet().toList(); // Remove duplicates
  }

  Future<Map<String, dynamic>?> _findProfileByPhone(String phone) async {
    final variants = _getPhoneFilterVariants(phone);
    if (variants.isEmpty) return null;

    // 1. Try exact inFilter matching first
    try {
      final List<dynamic> res = await client
          .from('profiles')
          .select()
          .inFilter('phone', variants)
          .limit(1);

      if (res.isNotEmpty) {
        return res.first as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('inFilter lookup failed: $e');
    }

    // 2. Fallback: Client-side digit matching against all profiles table rows
    try {
      final inputDigits = phone.replaceAll(RegExp(r'\D'), '');
      String inputBase = inputDigits;
      if (inputDigits.startsWith('62')) {
        inputBase = inputDigits.substring(2);
      } else if (inputDigits.startsWith('0')) {
        inputBase = inputDigits.substring(1);
      }

      if (inputBase.isEmpty) return null;

      final List<dynamic> allProfiles = await client
          .from('profiles')
          .select();

      for (final raw in allProfiles) {
        final profileMap = raw as Map<String, dynamic>;
        final storedPhone = (profileMap['phone'] ?? '').toString();
        final storedDigits = storedPhone.replaceAll(RegExp(r'\D'), '');

        String storedBase = storedDigits;
        if (storedDigits.startsWith('62')) {
          storedBase = storedDigits.substring(2);
        } else if (storedDigits.startsWith('0')) {
          storedBase = storedDigits.substring(1);
        }

        if (storedBase.isNotEmpty && storedBase == inputBase) {
          return profileMap;
        }
      }
    } catch (e) {
      debugPrint('Client-side fallback lookup failed: $e');
    }

    return null;
  }

  /// Check account status including dormant check (>60 days inactive or deactivated status)
  Future<AccountCheckResult> checkAccountStatus(String phone) async {
    try {
      debugPrint('checkAccountStatus input phone: "$phone"');
      final row = await _findProfileByPhone(phone);
      debugPrint('checkAccountStatus found profile: $row');

      if (row == null) {
        return AccountCheckResult(isRegistered: false);
      }

      final email = row['email'] as String?;
      final status = row['status'] as String?;
      final lastLoginStr = row['last_login_at'] ?? row['created_at'];

      bool isDormant = false;
      if (status == 'deactivated' || status == 'recycled') {
        isDormant = true;
      } else if (lastLoginStr != null) {
        final lastLoginDate = DateTime.tryParse(lastLoginStr.toString());
        if (lastLoginDate != null) {
          final differenceInDays = DateTime.now().toUtc().difference(lastLoginDate).inDays;
          if (differenceInDays >= 60) {
            isDormant = true;
          }
        }
      }

      return AccountCheckResult(
        isRegistered: true,
        isDormant: isDormant,
        email: email,
        phone: row['phone'] as String? ?? phone,
        status: status,
      );
    } catch (error, stackTrace) {
      debugPrint('Error checking account status: $error');
      debugPrint(stackTrace.toString());
      return AccountCheckResult(isRegistered: false);
    }
  }

  /// Check if a phone number is already registered in the profiles table
  Future<bool> checkPhoneExists(String phone) async {
    try {
      final profile = await _findProfileByPhone(phone);
      return profile != null;
    } catch (error) {
      debugPrint('Error checking phone existence: $error');
      return false; // Fail safe
    }
  }

  /// Verify user's birth date from Supabase profiles table
  Future<bool> verifyBirthDate({
    required String phone,
    required DateTime birthDate,
  }) async {
    try {
      final row = await _findProfileByPhone(phone);

      if (row == null || row['birth_date'] == null) {
        return true;
      }

      final String storedStr = row['birth_date'].toString();
      final storedDate = DateTime.tryParse(storedStr);
      if (storedDate == null) return true;

      return storedDate.year == birthDate.year &&
          storedDate.month == birthDate.month &&
          storedDate.day == birthDate.day;
    } catch (e) {
      debugPrint('Error verifying birth date: $e');
      return true;
    }
  }

  /// Update the user's PIN in Supabase profiles table
  Future<bool> updateUserPin({
    required String phone,
    required String newPin,
  }) async {
    try {
      final profile = await _findProfileByPhone(phone);
      if (profile == null) return false;

      final pinHash = hashPin(newPin);

      await client
          .from('profiles')
          .update({
            'pin_hash': pinHash,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', profile['id']);

      return true;
    } catch (error) {
      debugPrint('Error updating user PIN: $error');
      return false;
    }
  }

  /// Verify 6-digit PIN by comparing hashPin against stored pin_hash in profiles table
  Future<bool> verifyPin({
    required String phone,
    required String pin,
  }) async {
    try {
      final inputHash = hashPin(pin);
      final currentUser = client.auth.currentUser;

      Map<String, dynamic>? profile;

      // 1. Try to fetch by active session user ID first if available
      if (currentUser != null) {
        final List<dynamic> res = await client
            .from('profiles')
            .select('id, pin_hash, phone')
            .eq('id', currentUser.id)
            .limit(1);
        if (res.isNotEmpty) {
          profile = res.first as Map<String, dynamic>;
        }
      }

      // 2. If profile not found by currentUser ID, lookup by phone helper
      if (profile == null && phone.isNotEmpty) {
        profile = await _findProfileByPhone(phone);
      }

      if (profile == null) {
        throw Exception('Profile not found.');
      }

      final storedHash = (profile['pin_hash'] ?? '').toString();

      if (storedHash.isEmpty) {
        throw Exception('PIN not set for this account.');
      }

      if (storedHash != inputHash) {
        return false;
      }

      // Update last_login_at timestamp
      try {
        await client.from('profiles').update({
          'last_login_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', profile['id']);
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
}

class AccountCheckResult {
  AccountCheckResult({
    required this.isRegistered,
    this.isDormant = false,
    this.email,
    this.phone,
    this.status,
  });

  final bool isRegistered;
  final bool isDormant;
  final String? email;
  final String? phone;
  final String? status;
}

class AuthResult {
  AuthResult({required this.userId, required this.email, this.supabaseUser});

  final String userId;
  final String email;
  final User? supabaseUser;
}
