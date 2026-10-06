# Implementation Plan — Change Phone / Email Flow

## Context summary (read before implementing)

- **OTP pattern**: The app uses dummy codes `{'1234','5555','0000','9999'}` checked on the client. Real Supabase OTP is NOT used for this flow; the same pattern must be mirrored.
- **OTP box**: 4-digit, not 6-digit (matches `otp_verification_screen.dart` which uses `LengthLimitingTextInputFormatter(4)`).
- **Palette constants**: `_bg = Color(0xFFF0F7F7)`, `_c700 = Color(0xFF007F78)`, `_c500 = Color(0xFF00A79D)`, `_c100 = Color(0xFFD4F5F3)`, `_ink = Color(0xFF0E2C2F)`, `_ink2 = Color(0xFF3D6065)`, `_ink3 = Color(0xFF8AA8AC)`.
- **Supabase update**: `supabase_auth_service.dart` exposes `client.from('profiles').update({...}).eq('id', user.id)` directly from the screen. No new service method is required.
- **signOut**: `SupabaseAuthService().signOut()` then `Navigator.pushAndRemoveUntil → SignInScreen`.
- **Rate-limit check**: Query `profiles.updated_at` for the current user and compare to `DateTime.now().subtract(Duration(hours: 24))`.
- **Phone field pattern**: Indonesian flag widget + `'+62'` prefix exactly as in `sign_in_screen.dart` (`_buildIndonesianFlag()`).
- **Phone pre-fill**: `_loadProfile()` in `edit_profile_screen.dart` stores the phone as `'+62 XXXXX'`; strip `'+62 '` prefix before pre-filling the digits-only field.
- **Localization insertion**: New keys go at the very end of each language map, just before the closing `},` of `AppLanguage.en` and `AppLanguage.id` respectively. The EN map ends with `'genderFemaleValue': 'Perempuan',` and the ID map ends with the same key.

---

- [ ] 1. Add new localization keys to `app_language.dart`.
      Append the following keys to the **EN** map (just before `'genderFemaleValue': 'Perempuan',` → after it, before the closing `},`):
      ```dart
      // ── Change contact (phone / email) ──────────────────────────────
      'changePhoneTitle': 'Change Phone Number',
      'changeEmailTitle': 'Change Email',
      'changeContactCurrentLabel': 'Current value',
      'changeContactNewLabel': 'New value',
      'changeContactVerifyCurrentTitle': 'Verify Current Contact',
      'changeContactVerifyCurrentDesc': 'Enter the OTP sent to your current email to confirm your identity.',
      'changeContactVerifyNewTitle': 'Verify New Contact',
      'changeContactVerifyNewDesc': 'Enter the OTP sent to your new email to confirm the change.',
      'changeContactSuccessTitle': 'Change Successful!',
      'changeContactSuccessDesc': 'Your contact information has been updated. You will be signed out in {seconds} seconds.',
      'changePhoneWarning': 'Warning: Phone number can only be changed once per day and you cannot change email at the same time.',
      'changeEmailWarning': 'Warning: Email can only be changed once per day.',
      'changePhonePlaceholder': '08XX XXXX XXXX',
      'changeEmailPlaceholder': 'example@email.com',
      'changeContactRateLimitError': 'This contact information was already changed today. Please wait 24 hours.',
      'changeContactCurrentPhoneLabel': 'Current Phone Number',
      'changeContactNewPhoneLabel': 'New Phone Number',
      'changeContactCurrentEmailLabel': 'Current Email',
      'changeContactNewEmailLabel': 'New Email',
      'changeContactStep1Title': 'Enter Current {type}',
      'changeContactStep2Title': 'Verify Identity',
      'changeContactStep3Title': 'Enter New {type}',
      'changeContactStep4Title': 'Verify New {type}',
      'changeContactNextBtn': 'Continue',
      'changeContactResendOtp': 'Resend OTP',
      'changeContactResendIn': 'Resend in ',
      'changeContactOtpError': 'The OTP code is incorrect. Please try again.',
      'changePhone': 'Phone Number',
      'changeEmail': 'Email',
      ```
      Append the same keys to the **ID** map with Indonesian values:
      ```dart
      // ── Change contact (phone / email) ──────────────────────────────
      'changePhoneTitle': 'Ubah Nomor Telepon',
      'changeEmailTitle': 'Ubah Email',
      'changeContactCurrentLabel': 'Nilai saat ini',
      'changeContactNewLabel': 'Nilai baru',
      'changeContactVerifyCurrentTitle': 'Verifikasi Kontak Saat Ini',
      'changeContactVerifyCurrentDesc': 'Masukkan OTP yang dikirim ke email Anda saat ini untuk konfirmasi identitas.',
      'changeContactVerifyNewTitle': 'Verifikasi Kontak Baru',
      'changeContactVerifyNewDesc': 'Masukkan OTP yang dikirim ke email baru Anda untuk konfirmasi perubahan.',
      'changeContactSuccessTitle': 'Perubahan Berhasil!',
      'changeContactSuccessDesc': 'Informasi kontak Anda telah diperbarui. Anda akan keluar dalam {seconds} detik.',
      'changePhoneWarning': 'Peringatan: Nomor Telepon hanya bisa diubah 1x sehari dan tidak dapat mengubah email disaat yang sama.',
      'changeEmailWarning': 'Peringatan: Email hanya bisa diubah 1x sehari.',
      'changePhonePlaceholder': '08XX XXXX XXXX',
      'changeEmailPlaceholder': 'contoh@email.com',
      'changeContactRateLimitError': 'Informasi kontak ini sudah diubah hari ini. Harap tunggu 24 jam.',
      'changeContactCurrentPhoneLabel': 'Nomor Telepon Saat Ini',
      'changeContactNewPhoneLabel': 'Nomor Telepon Baru',
      'changeContactCurrentEmailLabel': 'Email Saat Ini',
      'changeContactNewEmailLabel': 'Email Baru',
      'changeContactStep1Title': 'Masukkan {type} Saat Ini',
      'changeContactStep2Title': 'Verifikasi Identitas',
      'changeContactStep3Title': 'Masukkan {type} Baru',
      'changeContactStep4Title': 'Verifikasi {type} Baru',
      'changeContactNextBtn': 'Lanjutkan',
      'changeContactResendOtp': 'Kirim Ulang OTP',
      'changeContactResendIn': 'Kirim ulang dalam ',
      'changeContactOtpError': 'Kode OTP tidak sesuai. Silakan coba lagi.',
      'changePhone': 'Nomor Telepon',
      'changeEmail': 'Email',
      ```
      Files: `lib/l10n/app_language.dart`
      Verify: `flutter analyze lib/l10n/app_language.dart` — no errors.

---

- [ ] 2. Create `lib/screens/home/change_contact_screen.dart`.
      Implement the complete `ChangeContactScreen` StatefulWidget with:

      **Enum and constants** (file-private):
      ```dart
      enum ChangeContactMode { phone, email }
      const _validDummyOtps = {'1234', '5555', '0000', '9999'};
      const _c700 = Color(0xFF007F78);
      const _c500 = Color(0xFF00A79D);
      const _c100 = Color(0xFFD4F5F3);
      const _bg  = Color(0xFFF0F7F7);
      const _ink  = Color(0xFF0E2C2F);
      const _ink2 = Color(0xFF3D6065);
      const _ink3 = Color(0xFF8AA8AC);
      ```

      **Constructor**:
      ```dart
      const ChangeContactScreen({
        super.key,
        required this.mode,
        this.currentValue, // pre-filled from profile
      });
      final ChangeContactMode mode;
      final String? currentValue;
      ```

      **State machine** (`int _step` 0..4):
      - Step 0: Current value input
        - Phone mode: Indonesian flag + '+62' prefix + digits-only TextField (hint `'08XX XXXX XXXX'`, `LengthLimitingTextInputFormatter(13)`) pre-filled from `currentValue` (strip `'+62 '` prefix first).
        - Email mode: standard email TextField pre-filled from `currentValue`.
        - On "Continue": validate non-empty; for phone validate Indonesian format; then **rate-limit check** (see below); on pass → `_step = 1`.
        - Warning text rendered below input in amber/orange style matching palette (`Color(0xFFB45309)` text, `Color(0xFFFEF3C7)` bg).
      - Step 1: OTP sent to current email — 4-box OTP, 60s countdown, resend. On correct dummy code → `_step = 2`.
      - Step 2: New value input (same field style as Step 0 but for the NEW value). On "Continue" → validate → `_step = 3`.
      - Step 3: OTP sent to new email — same 4-box OTP widget. On correct dummy code → call `_saveContact()` → `_step = 4`.
      - Step 4: Success screen — animated teal checkmark circle + success title + countdown from 3 to 0, then `SupabaseAuthService().signOut()` + `Navigator.pushAndRemoveUntil → SignInScreen`.

      **Rate-limit check** (called at Step 0 → Step 1 transition):
      ```dart
      Future<bool> _isRateLimited() async {
        final svc = SupabaseAuthService();
        final user = svc.client.auth.currentUser;
        if (user == null) return false;
        final row = await svc.client
            .from('profiles')
            .select('updated_at')
            .eq('id', user.id)
            .maybeSingle();
        if (row == null) return false;
        final updatedAt = DateTime.tryParse(row['updated_at']?.toString() ?? '');
        if (updatedAt == null) return false;
        return DateTime.now().toUtc().difference(updatedAt).inHours < 24;
      }
      ```
      If `_isRateLimited()` returns true, show error snackbar with `t(context, 'changeContactRateLimitError')` and stay on Step 0.

      **Save** (`_saveContact()`):
      ```dart
      Future<void> _saveContact() async {
        final svc = SupabaseAuthService();
        final user = svc.client.auth.currentUser;
        if (user == null) return;
        final field = mode == ChangeContactMode.phone ? 'phone' : 'email';
        final newValue = mode == ChangeContactMode.phone
            ? _newValueController.text.replaceAll(RegExp(r'\D'), '') // digits only
            : _newValueController.text.trim();
        await svc.client.from('profiles').update({
          field: newValue,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', user.id);
        if (mode == ChangeContactMode.email) {
          try { await svc.client.auth.updateUser(UserAttributes(email: newValue)); }
          catch (_) {} // best-effort; don't block success
        }
      }
      ```

      **OTP widget** (private method `_buildOtpBoxes`): copy the exact 4-box pattern from `otp_verification_screen.dart` — `LayoutBuilder` + `GestureDetector` tap → `_focusNode.requestFocus()` + hidden `TextField` + blinking cursor widget. Accept `TextEditingController` and `FocusNode` as parameters so it can be reused for steps 1 and 3.

      **Step indicator**: 5 dots matching `_buildStepIndicator` from `otp_verification_screen.dart` but driven by `_step + 1`.

      **Scaffold**: `backgroundColor: _bg`, `AppBar` with back arrow (pops to edit profile), centered title from localization key.

      **Card container** for each step:
      ```dart
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _ink.withValues(alpha: 0.04), blurRadius: 24, offset: Offset(0, 8))],
        ),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        ...
      )
      ```

      **Primary button**: gradient `[Color(0xFF007F78), Color(0xFF00A79D)]`, 52px height, 16px radius, same as sign_in_screen.

      Files: `lib/screens/home/change_contact_screen.dart`
      Verify: `flutter analyze lib/screens/home/change_contact_screen.dart` — no errors.

---

- [ ] 3. Modify `edit_profile_screen.dart` — phone and email rows.
      
      **Phone row** (row 6, currently read-only with eye toggle): replace the entire `_infoRow(...)` block for phone with:
      ```dart
      _infoRow(
        icon: Icons.phone_iphone_rounded,
        label: t(context, 'phoneNumber'),
        value: _displayPhone,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeContactScreen(
                mode: ChangeContactMode.phone,
                currentValue: _phone,
              ),
            ),
          );
          _loadProfile();
        },
      ),
      ```
      Remove the `showChevron: false` and the `trailing: IconButton(...)` eye-toggle.
      Add the import: `import 'change_contact_screen.dart';`
      
      **Email row** (row 7, currently read-only, no onTap): replace with:
      ```dart
      _infoRow(
        icon: Icons.email_outlined,
        label: t(context, 'email'),
        value: _maskEmail(_email),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeContactScreen(
                mode: ChangeContactMode.email,
                currentValue: _email,
              ),
            ),
          );
          _loadProfile();
        },
      ),
      ```
      (Remove `showChevron: false` so the default chevron shows.)

      Also remove the now-unused `_hidePhone` field and `_displayPhone` getter and `setState(() => _hidePhone = !_hidePhone)` call — the phone value is no longer masked behind an eye toggle. Replace all `_displayPhone` references with direct display of `_phone ?? '-'` in the row value.

      Files: `lib/screens/home/edit_profile_screen.dart`
      Verify: `flutter analyze lib/screens/home/edit_profile_screen.dart` — no errors.

---

- [ ] 4. Final cross-file analysis.
      Run `flutter analyze lib/screens/home/change_contact_screen.dart lib/screens/home/edit_profile_screen.dart lib/l10n/app_language.dart` and fix any reported issues (unused imports, missing `const`, type mismatches) until the command exits with zero issues.
      Files: (no additional changes unless analyze reveals them)
      Verify: `flutter analyze lib/screens/home/change_contact_screen.dart lib/screens/home/edit_profile_screen.dart lib/l10n/app_language.dart` — output ends with "No issues found!" or only info-level hints (no errors or warnings).
