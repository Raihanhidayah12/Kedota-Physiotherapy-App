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
    final supabaseUrl =
        dotenv.env['SUPABASE_URL'] ??
        const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://wwmctqhbqpsbkyxkeaqv.supabase.co',
        );
    return SupabaseApiClient(dio, baseUrl: '$supabaseUrl/rest/v1');
  }

  String buildEmailFromPhone(String phone) {
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    return '$normalized@kedota.local';
  }

  /// Format DateTime ke "YYYY-MM-DD" tanpa konversi timezone
  /// Menggunakan year/month/day langsung dari local DateTime untuk menghindari
  /// masalah timezone saat menyimpan ke database
  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String resolveAuthEmail(String phone, {String? suppliedEmail}) {
    final trimmedEmail = suppliedEmail?.trim() ?? '';
    if (trimmedEmail.isNotEmpty &&
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmedEmail)) {
      return trimmedEmail;
    }
    return buildEmailFromPhone(phone);
  }

  String hashPin(String pin) {    final bytes = utf8.encode(pin);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  String hashPinLegacy(String pin) {
    final bytes = utf8.encode(pin);
    var hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _formatSupabaseError(Object error) {
    if (error is AuthException) {
      // Handle specific auth errors
      if (error.message.contains('User already registered')) {
        return 'Email atau nomor telepon sudah terdaftar. Silakan login.';
      }
      if (error.message.contains('Invalid email')) {
        return 'Format email tidak valid. Silakan gunakan email yang valid.';
      }
      if (error.message.contains('Email rate limit exceeded') ||
          error.message.contains('rate limit')) {
        return 'Terlalu banyak percobaan. Silakan tunggu beberapa menit dan coba lagi.';
      }
      if (error.message.contains('already been registered') ||
          error.message.contains('already registered')) {
        return 'Akun dengan email ini sudah terdaftar. Silakan login atau gunakan email lain.';
      }
      return error.message;
    }

    final message = error.toString();
    if (message.contains('Database error saving new user')) {
      return 'Gagal membuat akun. Silakan coba lagi atau hubungi support.';
    }
    if (message.contains('Email address') && message.contains('is invalid')) {
      return 'Format email tidak valid. Silakan gunakan email yang benar.';
    }
    if (message.contains('rate limit')) {
      return 'Terlalu banyak percobaan. Silakan tunggu beberapa menit dan coba lagi.';
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
          id: 'eq.$userId',
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
          'auth_email': authEmail,
          'birth_date': _formatDate(birthDate),
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
      debugPrint(
        'signInWithPhone: raw phone=$phone normalizedPhone=$normalizedPhone',
      );

      // Look up the profile by phone number (get auth_email if exists)
      final profile = await _findProfileByPhone(phone);
      debugPrint('signInWithPhone: profile found=${profile != null}');

      if (profile == null) {
        throw Exception('phoneNotRegisteredOrIncomplete');
      }

      // Verify PIN against stored hash
      final storedHash = profile['pin_hash'] as String?;
      final inputHash = hashPin(pin);

      if (storedHash == null || storedHash != inputHash) {
        throw Exception('Invalid PIN');
      }

      // Get auth email candidates. Auth identity may be stored in auth_email,
      // or the fallback can be the profile email or the generated phone identity.
      final authEmailCandidates = <String>{
        if (profile['auth_email'] is String &&
            (profile['auth_email'] as String).isNotEmpty)
          profile['auth_email'] as String,
        if (profile['email'] is String &&
            (profile['email'] as String).isNotEmpty)
          profile['email'] as String,
        buildEmailFromPhone(phone),
      }.toList();

      debugPrint(
        'signInWithPhone: normalizedPhone=$normalizedPhone authEmailCandidates=$authEmailCandidates',
      );

      User? user;
      String? usedEmail;
      Object? lastSignInError;

      for (final candidate in authEmailCandidates) {
        try {
          debugPrint('signInWithPhone: trying authEmail=$candidate');
          final response = await client.auth.signInWithPassword(
            email: candidate,
            password: pin,
          );
          debugPrint(
            'signInWithPhone: auth response user=${response.user?.id}',
          );
          if (response.user != null) {
            user = response.user;
            usedEmail = candidate;
            break;
          }
        } catch (error) {
          debugPrint(
            'signInWithPhone: auth sign-in failed for $candidate: $error',
          );
          lastSignInError = error;
        }
      }

      if (user == null) {
        throw Exception(lastSignInError?.toString() ?? 'Invalid phone or PIN.');
      }
      debugPrint('signInWithPhone: signed in with email=$usedEmail');

      // Update last login timestamp
      await _persistProfile(
        userId: user.id,
        email: usedEmail ?? buildEmailFromPhone(phone),
        password: pin,
        isUpdate: true,
        profileData: {
          'last_login_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      return AuthResult(
        userId: user.id,
        email: usedEmail ?? buildEmailFromPhone(phone),
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
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          const webClientId =
              '1070539718443-c8ukpkb6cde0h401nkc0j7v1g03err91.apps.googleusercontent.com';
          final googleSignIn = GoogleSignIn(serverClientId: webClientId);
          // Sign out dulu agar dialog pilih akun selalu muncul
          await googleSignIn.signOut();
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
          debugPrint(
            'Native Google Sign-In failed, falling back to OAuth Web: $nativeError',
          );
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

  Future<void> signInWithApple({String? redirectTo}) async {
    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: redirectTo,
      );
    } catch (error, stackTrace) {
      debugPrint('Supabase Apple signIn failed: $error');
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
        await client.auth.updateUser(UserAttributes(password: pin));
      } catch (authErr) {
        debugPrint(
          'Notice: Auth password update optional for social session: $authErr',
        );
      }

      final profilePayload = {
        'id': user.id,
        'phone': normalizedPhone,
        'full_name': fullName,
        'email': user.email ?? email,
        'auth_email': user.email ?? email,
        'birth_date': _formatDate(birthDate),
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

      return AuthResult(
        userId: user.id,
        email: user.email ?? email,
        supabaseUser: user,
      );
    } catch (error, stackTrace) {
      debugPrint('Supabase completeSocialProfile failed: $error');
      debugPrint(stackTrace.toString());
      throw Exception(_formatSupabaseError(error));
    }
  }

  /// Create profile for phone sign up (after OTP verification).
  ///
  /// Uses the user's real email as the Supabase auth identity so that
  /// a later Google sign-in with the same email can be linked to this account
  /// via manual linking.  "Confirm email" must be disabled in the Supabase
  /// dashboard (Authentication → Sign in / Providers) for this to work without
  /// hitting the email send rate limit.
  ///
  /// Falls back to a generated `phone@kedota.local` email only when the user
  /// did not supply a valid email address.
  Future<AuthResult> createPhoneProfile({
    required String phone,
    required String fullName,
    required String email,
    required DateTime birthDate,
    required String gender,
    required String pin,
  }) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'\D'), '');

    // Use the real email as auth identity so Google linking works later.
    // Fall back to generated email only if user didn't provide a valid one.
    final hasRealEmail = email.trim().isNotEmpty && _isValidEmail(email.trim());
    final authEmail = hasRealEmail ? email.trim() : buildEmailFromPhone(phone);
    final displayEmail = authEmail;

    // --- Step 1: try to sign in — the user may already have a partial auth record ---
    try {
      final signInResponse = await client.auth.signInWithPassword(
        email: authEmail,
        password: pin,
      );
      final existingUser = signInResponse.user;
      if (existingUser != null) {
        // Auth user exists; upsert the profile and return.
        debugPrint(
          'createPhoneProfile: existing auth user found, upserting profile',
        );
        await _upsertPhoneProfile(
          userId: existingUser.id,
          authEmail: authEmail,
          displayEmail: displayEmail,
          normalizedPhone: normalizedPhone,
          fullName: fullName,
          birthDate: birthDate,
          gender: gender,
          pin: pin,
        );
        return AuthResult(
          userId: existingUser.id,
          email: authEmail,
          supabaseUser: existingUser,
        );
      }
    } on AuthException catch (signInErr) {
      // Expected for new users — "Invalid login credentials" means no account yet.
      // Any other error (e.g. network) is ignored so we fall through to signUp.
      debugPrint('createPhoneProfile: signIn pre-check: ${signInErr.message}');
    } catch (_) {
      // Non-auth error — continue to signUp.
    }

    // --- Step 2: sign up (creates the Supabase Auth user) ---
    try {
      final response = await client.auth.signUp(
        email: authEmail,
        password: pin,
        data: {
          'phone': normalizedPhone,
          'full_name': fullName,
          'signup_method': 'phone',
        },
        emailRedirectTo: null,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Unable to create Supabase account.');
      }

      // Ensure we have an active session before upserting the profile.
      // Some Supabase setups may not automatically persist the session after sign-up.
      if (client.auth.currentSession == null) {
        await client.auth.signInWithPassword(email: authEmail, password: pin);
      }

      await _upsertPhoneProfile(
        userId: user.id,
        authEmail: authEmail,
        displayEmail: displayEmail,
        normalizedPhone: normalizedPhone,
        fullName: fullName,
        birthDate: birthDate,
        gender: gender,
        pin: pin,
      );

      return AuthResult(userId: user.id, email: authEmail, supabaseUser: user);
    } on AuthException catch (authError) {
      debugPrint('createPhoneProfile signUp error: $authError');

      if (authError.message.toLowerCase().contains('rate limit') ||
          authError.statusCode == '429') {
        // Surface immediately — do NOT retry.
        throw Exception(
          'Terlalu banyak percobaan pendaftaran. Silakan tunggu beberapa menit dan coba lagi.',
        );
      }

      if (authError.message.contains('already registered') ||
          authError.message.contains('User already registered')) {
        // Race condition: account was created between our signIn check and signUp.
        // Try signing in one more time.
        try {
          final retrySignIn = await client.auth.signInWithPassword(
            email: authEmail,
            password: pin,
          );
          final retryUser = retrySignIn.user;
          if (retryUser != null) {
            await _upsertPhoneProfile(
              userId: retryUser.id,
              authEmail: authEmail,
              displayEmail: displayEmail,
              normalizedPhone: normalizedPhone,
              fullName: fullName,
              birthDate: birthDate,
              gender: gender,
              pin: pin,
            );
            return AuthResult(
              userId: retryUser.id,
              email: authEmail,
              supabaseUser: retryUser,
            );
          }
        } catch (retryErr) {
          debugPrint('createPhoneProfile retry signIn failed: $retryErr');
        }
      }

      throw Exception(_formatSupabaseError(authError));
    } catch (error, stackTrace) {
      debugPrint('Supabase createPhoneProfile failed: $error');
      debugPrint(stackTrace.toString());
      throw Exception(_formatSupabaseError(error));
    }
  }

  /// Upserts a phone-signup profile row. Used by [createPhoneProfile].
  Future<void> _upsertPhoneProfile({
    required String userId,
    required String authEmail,
    required String displayEmail,
    required String normalizedPhone,
    required String fullName,
    required DateTime birthDate,
    required String gender,
    required String pin,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await client.from('profiles').upsert({
        'id': userId,
        'phone': normalizedPhone,
        'full_name': fullName,
        'email': displayEmail,
        'auth_email': authEmail,
        'birth_date': _formatDate(birthDate),
        'gender': gender,
        'signup_method': 'phone',
        'pin_hash': hashPin(pin),
        'is_profile_complete': true,
        'created_at': now,
        'updated_at': now,
      });
    } catch (upsertErr) {
      debugPrint(
        '_upsertPhoneProfile upsert failed, trying _persistProfile: $upsertErr',
      );
      await _persistProfile(
        userId: userId,
        email: authEmail,
        password: pin,
        profileData: {
          'id': userId,
          'phone': normalizedPhone,
          'full_name': fullName,
          'email': displayEmail,
          'auth_email': authEmail,
          'birth_date': _formatDate(birthDate),
          'gender': gender,
          'signup_method': 'phone',
          'pin_hash': hashPin(pin),
          'is_profile_complete': true,
          'created_at': now,
          'updated_at': now,
        },
      );
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email);
  }

  /// Check if email already exists in profiles table
  Future<bool> checkEmailExists(String email) async {
    if (email.trim().isEmpty) return false;

    try {
      final result = await client
          .from('profiles')
          .select('email')
          .eq('email', email.trim())
          .maybeSingle();

      return result != null; // If result exists, email is taken
    } catch (e) {
      debugPrint('Error checking email: $e');
      return false; // On error, allow user to proceed (will catch on signup)
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

    final list = ['62$base', '+62$base', '0$base', digits];
    return list.toSet().toList(); // Remove duplicates
  }

  Future<Map<String, dynamic>?> _findProfileByPhone(String phone) async {
    final variants = _getPhoneFilterVariants(phone);
    debugPrint('findProfileByPhone: phone=$phone variants=$variants');
    if (variants.isEmpty) return null;

    // 1. Try exact inFilter matching first
    try {
      final List<dynamic> res = await client
          .from('profiles')
          .select()
          .inFilter('phone', variants)
          .limit(1);

      if (res.isNotEmpty) {
        debugPrint(
          'findProfileByPhone: found profile id=${(res.first as Map<String, dynamic>)['id']}',
        );
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

      final List<dynamic> allProfiles = await client.from('profiles').select();

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
          final differenceInDays = DateTime.now()
              .toUtc()
              .difference(lastLoginDate)
              .inDays;
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
      if (profile == null) return false;

      // Kalau nomor ditemukan tapi itu milik user yang sedang login sekarang,
      // anggap belum exist — user ini sedang melengkapi profilnya sendiri
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId != null && profile['id']?.toString() == currentUserId) {
        return false;
      }

      return true;
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

      debugPrint('verifyBirthDate phone: $phone');
      debugPrint('verifyBirthDate row found: ${row != null}');
      debugPrint('verifyBirthDate stored birth_date: ${row?['birth_date']}');
      debugPrint(
        'verifyBirthDate input: ${birthDate.year}-${birthDate.month}-${birthDate.day}',
      );

      if (row == null || row['birth_date'] == null) {
        // Tidak ada data → loloskan (jangan blokir user)
        return true;
      }

      final String storedStr = row['birth_date'].toString().trim();
      // Format DB bisa: "2000-01-01" atau "2000-01-01T00:00:00"
      // Ambil hanya bagian tanggal saja
      final datePart = storedStr.length >= 10
          ? storedStr.substring(0, 10)
          : storedStr;
      final parts = datePart.split('-');
      if (parts.length != 3) return true;

      final storedYear = int.tryParse(parts[0]);
      final storedMonth = int.tryParse(parts[1]);
      final storedDay = int.tryParse(parts[2]);

      if (storedYear == null || storedMonth == null || storedDay == null) {
        return true;
      }

      debugPrint(
        'verifyBirthDate parsed stored: $storedYear-$storedMonth-$storedDay',
      );
      debugPrint(
        'verifyBirthDate input local: ${birthDate.year}-${birthDate.month}-${birthDate.day}',
      );

      return storedYear == birthDate.year &&
          storedMonth == birthDate.month &&
          storedDay == birthDate.day;
    } catch (e) {
      debugPrint('Error verifying birth date: $e');
      return true;
    }
  }

  /// URL Supabase Edge Function untuk update PIN.
  /// Semua operasi yang butuh service-role key (update profiles + sync auth
  /// password) dilakukan di server — Flutter hanya kirim JWT + PIN hash.
  String get _updatePinFunctionUrl {
    final url =
        dotenv.env['SUPABASE_URL'] ??
        const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://wwmctqhbqpsbkyxkeaqv.supabase.co',
        );
    return '$url/functions/v1/update-pin';
  }

  /// Update PIN user via Supabase Edge Function.
  ///
  /// Alur:
  /// 1. Cari profil by phone → dapat profile_id dan pin_hash lama
  /// 2. Validasi allowSamePin
  /// 3. Kirim ke Edge Function: { profile_id, new_pin_hash, new_pin }
  ///    dengan Authorization: Bearer `anon_key_or_session_token`
  /// 4. Edge Function menggunakan service-role key di sisi server untuk:
  ///    - Update pin_hash di tabel profiles
  ///    - Sync password di Supabase Auth via admin.updateUserById
  Future<bool> updateUserPin({
    required String phone,
    required String newPin,
    bool allowSamePin = false,
  }) async {
    try {
      final profile = await _findProfileByPhone(phone);
      if (profile == null) return false;

      final newPinHash = hashPin(newPin);
      final oldPinHash = (profile['pin_hash'] ?? '').toString();
      debugPrint(
        'updateUserPin: oldPinHash=${oldPinHash.isNotEmpty ? oldPinHash.substring(0, 8) : 'empty'}... '
        'newPinHash=${newPinHash.substring(0, 8)}...',
      );

      // Tolak jika PIN baru sama dengan PIN lama (kecuali dari alur lupa PIN)
      if (!allowSamePin && newPinHash == oldPinHash) {
        throw Exception('sameAsOldPin');
      }

      final profileId = profile['id'].toString();
      final currentUser = client.auth.currentUser;
      debugPrint(
        'updateUserPin: profileId=$profileId currentUser=${currentUser?.id}',
      );

      // Jika user punya session aktif dan itu miliknya sendiri,
      // update langsung tanpa Edge Function (lebih cepat, tidak perlu network hop)
      if (currentUser != null && currentUser.id == profileId) {
        debugPrint('updateUserPin: using current session for direct update');

        await client
            .from('profiles')
            .update({
              'pin_hash': newPinHash,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', profileId);

        await client.auth.updateUser(UserAttributes(password: newPin));
        debugPrint('updateUserPin: direct session update successful');
        return true;
      }

      // Tidak ada session aktif (alur lupa PIN) — delegasikan ke Edge Function
      debugPrint('updateUserPin: no active session, calling Edge Function');

      // Token untuk autentikasi ke Edge Function:
      // Gunakan session token jika ada, fallback ke anon key
      final token =
          client.auth.currentSession?.accessToken ?? _supabasePublishableKey;

      final dio = Dio();
      final response = await dio.post(
        _updatePinFunctionUrl,
        data: {
          'profile_id': profileId,
          'new_pin_hash': newPinHash,
          'new_pin': newPin,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      debugPrint(
        'updateUserPin: Edge Function response status=${response.statusCode} data=${response.data}',
      );

      if (response.statusCode == 200) {
        return true;
      }

      throw Exception(
        'Edge Function returned ${response.statusCode}: ${response.data}',
      );
    } on DioException catch (e, st) {
      debugPrint('updateUserPin DioException: ${e.response?.data}');
      debugPrint(st.toString());
      final detail = e.response?.data?['error'] ?? e.message ?? 'Unknown error';
      throw Exception('Unable to update PIN: $detail');
    } catch (error) {
      debugPrint('Error updating user PIN: $error');
      rethrow;
    }
  }

  /// Verify 6-digit PIN by comparing hashPin against stored pin_hash in profiles table
  Future<bool> verifyPin({required String phone, required String pin}) async {
    try {
      final inputHash = hashPin(pin);
      debugPrint(
        'verifyPin: phone=$phone inputHash=${inputHash.substring(0, 8)}...',
      );
      Map<String, dynamic>? profile;

      // First try to find the profile by the phone number in the current flow.
      if (phone.isNotEmpty) {
        profile = await _findProfileByPhone(phone);
      }

      // If the phone lookup didn't find a profile, fall back to the active session user.
      if (profile == null) {
        final currentUser = client.auth.currentUser;
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
      }

      if (profile == null) {
        throw Exception('Profile not found.');
      }

      final storedHash = (profile['pin_hash'] ?? '').toString();
      debugPrint(
        'verifyPin: profileId=${profile['id']} phone=${profile['phone']} auth_email=${profile['auth_email']} email=${profile['email']} storedHash=${storedHash.substring(0, storedHash.length > 8 ? 8 : storedHash.length)}...',
      );

      if (storedHash.isEmpty) {
        throw Exception('PIN not set for this account.');
      }

      if (storedHash == inputHash) {
        try {
          await client
              .from('profiles')
              .update({
                'last_login_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', profile['id']);
        } catch (_) {}
        return true;
      }

      final legacyHash = hashPinLegacy(pin);
      debugPrint(
        'verifyPin: fallback legacyHash=${legacyHash.substring(0, 8)}... storedHash=${storedHash.substring(0, storedHash.length > 8 ? 8 : storedHash.length)}...',
      );
      if (storedHash == legacyHash) {
        try {
          await client
              .from('profiles')
              .update({
                'last_login_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', profile['id']);
        } catch (_) {}
        return true;
      }

      return false;
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
