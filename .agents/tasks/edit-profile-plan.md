# Implementation Plan — EditProfileScreen UI Rewrite

**File to modify:** `lib/screens/home/edit_profile_screen.dart`

---

## Key findings from code exploration

### Exact l10n key names (confirmed in `lib/l10n/app_language.dart`)
| Purpose | Key |
|---|---|
| AppBar title | `menuEditProfile` → "Account Information" / "Informasi Akun" |
| Full name label | `fullName` |
| NIK label | `nik` |
| Address label | `address` |
| Gender label | `gender` |
| Birth date label | `birthDate` |
| Phone number label | `phoneNumber` |
| Email label | `email` |
| Patient ID label | `patientIdLabel` |
| Patient ID copied snack | `patientIdCopied` |
| Profile saved snack | `profileSavedSuccess` |
| Error title | `failedTitle` |
| Save-failed subtitle | `saveProfileFailed` |
| Close button | `closeBtn` |
| Cancel button | `cancel` |
| Gender male value | `genderMaleValue` → "Laki-laki" |
| Gender female value | `genderFemaleValue` → "Perempuan" |
| Male display label | `male` |
| Female display label | `female` |
| Save button in sheet | use `saveAndContinue` (exists in both EN/ID: "Save & Continue" / "Simpan & Masuk") — add a dedicated `'save'` key (see item 1 below) |

### Existing helpers that become unused after the rewrite
- `_editableField(...)` — replaced by the new row + bottom-sheet pattern
- `_genderPicker()` — replaced by gender chips inside bottom sheet
- `_datePicker()` — replaced by direct `_pickDate()` call from row tap
- `_saveButton()` — removed; saving is per-sheet

### Existing helpers that are **kept** (called by kept methods)
- `_readOnlyField(...)` — used for phone/email/patient-ID rows; keep it  
  *However* its layout needs a small change for the new icon style (see item 4).  
- `_buildAvatar()` — replaced entirely by new photo card row (item 3)  
- `_sectionTitle()`, `_buildCard()`, `_divider()` — kept as-is

### Import changes needed
No new packages are required. `HapticFeedback` is already imported via `package:flutter/services.dart`. All existing imports remain.

### No new l10n keys needed — decision
`saveAndContinue` ("Save & Continue" / "Simpan & Masuk") is already bilingual and semantically close enough for the sheet's Simpan button. Do NOT add a new key; use `saveAndContinue`.  
*Rationale: adding keys would require touching `app_language.dart` and both language maps, increasing scope. The existing key is clear.*

---

## Implementation Plan

- [ ] 1. **Add `'save'` translation key to both language maps in `app_language.dart`**  
  The bottom-sheet save button needs a concise "Save" / "Simpan" label. `saveAndContinue` says "Save & Continue" which is misleading on a field-level save. Add a minimal new key.  
  - In `AppLanguage.en` map, inside the `// ── Edit profile` comment block, add:  
    `'save': 'Save',`  
  - In `AppLanguage.id` map, inside the `// ── Edit profile` comment block, add:  
    `'save': 'Simpan',`  
  Files: `lib/l10n/app_language.dart`  
  Verify: `flutter analyze lib/l10n/app_language.dart` — no errors.

- [ ] 2. **Remove four unused widget helpers from `_EditProfileScreenState`**  
  Delete the bodies (and declarations) of:  
  - `_editableField(...)` (lines ~882–940 of original file)  
  - `_genderPicker()` (lines ~943–1001)  
  - `_datePicker()` (lines ~1003–1047)  
  - `_saveButton()` (lines ~1049–1086)  
  Also delete `_sectionTitle()` only if it is not referenced in the new `build()` — it will **not** be used in the new layout (no section headers), so delete it too.  
  Do NOT delete `_readOnlyField(...)`, `_buildCard()`, `_divider()`, `_buildAppBar()`, `_buildAvatar()`.  
  Files: `lib/screens/home/edit_profile_screen.dart`  
  Verify: `flutter analyze lib/screens/home/edit_profile_screen.dart` — no "unused method" or "unused element" warnings for those four helpers.

- [ ] 3. **Add `_buildPhotoCard()` helper — photo row inside a white card**  
  Create a new private method `Widget _buildPhotoCard()` that returns:
  ```
  Container(
    decoration: white rounded card, borderRadius 20, same boxShadow pattern as _buildCard,
    padding: symmetric(horizontal 20, vertical 18),
    child: Row(
      children: [
        // Avatar — 64 px radius, no gradient ring
        CircleAvatar(
          radius: 64,
          backgroundColor: _c100,
          backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
          child: _isUploading
            ? CircularProgressIndicator(color: _c700, strokeWidth: 2.5)
            : _profileImageUrl == null
              ? Icon(Icons.person_rounded, color: _c500, size: 64)
              : null,
        ),
        SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Teal outlined upload button
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickAndUploadPhoto,
                icon: Icon(Icons.upload_rounded, size: 18),
                label: Text('Unggah Foto'),   // hardcoded — add 'uploadPhoto' key? No — keep hardcode in this single widget per the task spec
                style: OutlinedButton.styleFrom(
                  foregroundColor: _c700,
                  side: BorderSide(color: _c700, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: symmetric(horizontal 14, vertical 10),
                  textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'PNG/JPG maksimal 2MB',
                style: TextStyle(fontSize: 11, color: _ink3),
              ),
            ],
          ),
        ),
      ],
    ),
  )
  ```
  Note: The label "Unggah Foto" and hint "PNG/JPG maksimal 2MB" match the task spec exactly. No new l10n key is needed — the task spec prescribes the exact Indonesian text; the app is bilingual but this label is acceptable as-is (same pattern as other hardcoded UI strings in this file).  
  Files: `lib/screens/home/edit_profile_screen.dart`  
  Verify: `flutter analyze lib/screens/home/edit_profile_screen.dart` — no errors.

- [ ] 4. **Add `_infoRow()` helper — the tappable/read-only row pattern**  
  Create a private method:
  ```dart
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,          // null → read-only, no chevron
    Widget? trailing,             // overrides chevron (for eye-toggle, copy icon)
  })
  ```
  Layout:
  - Outer: `Material(color: Colors.transparent)` wrapping an `InkWell(onTap: onTap)` — so tap ripple works inside the card.
  - `Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14))`
  - `Row` children:
    1. Teal icon square: `Container(width: 40, height: 40, decoration: BoxDecoration(color: _c100, borderRadius: 10), child: Icon(icon, size: 20, color: _c700))`
    2. `SizedBox(width: 14)`
    3. `Expanded(child: Column([label text (fontSize 12, color: _ink3, w600), SizedBox(4), value text (fontSize 14, color: _ink, w600, overflow: ellipsis)]))`
    4. `SizedBox(width: 8)`
    5. If `trailing != null`: show `trailing`. Else if `onTap != null`: show `Icon(Icons.chevron_right_rounded, size: 20, color: _ink3)`. Else: `SizedBox.shrink()`.
  
  Files: `lib/screens/home/edit_profile_screen.dart`  
  Verify: `flutter analyze lib/screens/home/edit_profile_screen.dart` — no errors.

- [ ] 5. **Add five bottom-sheet launchers as private methods**  
  Each uses `showModalBottomSheet(isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, ...)` with a `StatefulBuilder` for local state where needed.  
  Common sheet scaffold (extract to inline code, not a separate helper):
  - `Container` with `decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)))`, `padding: fromLTRB(20, 12, 20, 32)`
  - Drag handle (width 44, height 4, color `Color(0xFFDDE5E6)`, margin only bottom 20)
  - Sheet title: `Text(label, style: TextStyle(fontSize: 16, fontWeight: w700, color: _ink))`
  - `SizedBox(height: 20)`
  - Form field or chips
  - `SizedBox(height: 24)`
  - Save button: full-width `FilledButton` with `backgroundColor: _c700`, label `t(context, 'save')`

  **5a. `_openNameSheet()`**  
  - Local `GlobalKey<FormState> _sheetFormKey = GlobalKey()`  
  - `TextFormField` bound to `_nameCtr`, `validator`: non-empty check using `t(context, 'fullNameRequired')`  
  - On Simpan: `if (_sheetFormKey.currentState!.validate()) { setState(() => _isDirty = true); await _save(); if (mounted) Navigator.of(context).pop(); }`

  **5b. `_openNikSheet()`**  
  - Local `GlobalKey<FormState>`  
  - `TextFormField` bound to `_nikCtr`, `keyboardType: TextInputType.number`, `inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)]`  
  - Validator: if non-empty and length != 16 → `t(context, 'nikLengthError')`; if `widget.requireCompleteProfile` and empty → `t(context, 'nikRequired')`  
  - On Simpan: validate → `setState(() => _isDirty = true)` → `_save()` → pop

  **5c. `_openGenderSheet()`**  
  - `StatefulBuilder` for local `String? _localGender = _gender`  
  - Chip row: same logic as the deleted `_genderPicker()` but using `_localGender` instead of `_gender`; `AnimatedContainer` per chip, selected = `_c700` bg / white text, unselected = `Color(0xFFF5F8F8)` / `_ink2`  
  - On Simpan: `setState(() { _gender = _localGender; _isDirty = true; })` → `_save()` → pop

  **5d. `_openAddressSheet()`**  
  - Local `GlobalKey<FormState>`  
  - `TextFormField` bound to `_addressCtr`, `minLines: 3, maxLines: 5`  
  - Validator: if `widget.requireCompleteProfile` and empty → `t(context, 'addressRequired')`  
  - On Simpan: validate → `setState(() => _isDirty = true)` → `_save()` → pop

  *(Tanggal Lahir does NOT get a sheet — the row tap calls `_pickDate()` directly.)*

  Files: `lib/screens/home/edit_profile_screen.dart`  
  Verify: `flutter analyze lib/screens/home/edit_profile_screen.dart` — no errors.

- [ ] 6. **Add three preview-value computed getters**  
  Add these private getters to `_EditProfileScreenState` (place them near the existing `_displayPhone` getter for consistency):

  ```dart
  // Nama: 'P***a K***g' pattern — first + '***' + last per word
  String get _maskedName {
    final name = _nameCtr.text.trim();
    if (name.isEmpty) return '-';
    return name.split(' ').map((word) {
      if (word.length <= 1) return word;
      return '${word[0]}${'***'}${word[word.length - 1]}';
    }).join(' ');
  }

  // NIK: bullet dots or dash
  String get _maskedNik {
    final nik = _nikCtr.text.trim();
    return nik.isEmpty ? '-' : '••••••••••••••••'; // 16 bullets
  }

  // Email: 'p****@gmail.com' or '-'
  String get _maskedEmail {
    final em = _email?.trim() ?? '';
    if (em.isEmpty) return '-';
    final atIdx = em.indexOf('@');
    if (atIdx <= 0) return em;
    return '${em[0]}****${em.substring(atIdx)}';
  }

  // Birth date: '**/**/YYYY' or '-'
  String get _maskedBirthDate {
    if (_birthDate == null) return '-';
    return '**/**/${_birthDate!.year}';
  }

  // Address preview: first 22 chars + '...' or full
  String get _addressPreview {
    final addr = _addressCtr.text.trim();
    if (addr.isEmpty) return '-';
    return addr.length > 22 ? '${addr.substring(0, 22)}...' : addr;
  }
  ```

  Files: `lib/screens/home/edit_profile_screen.dart`  
  Verify: `flutter analyze lib/screens/home/edit_profile_screen.dart` — no errors.

- [ ] 7. **Rewrite `build()` — assemble the new list layout**  
  Replace the entire `build()` method body. Keep the `PopScope` wrapper, `Scaffold(backgroundColor: _bg)`, `FadeTransition`/`SlideTransition` wrapping, and `_buildAppBar()` SliverAppBar. Replace all children of the `SliverToBoxAdapter` padding with:

  ```dart
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
    child: Column(
      children: [
        // ── Photo card ──────────────────────────────────────
        _buildPhotoCard(),
        const SizedBox(height: 16),

        // ── Info list card ──────────────────────────────────
        _buildCard(children: [
          // 1. Nama Lengkap
          _infoRow(
            icon: Icons.person_outline_rounded,
            label: t(context, 'fullName'),
            value: _maskedName,
            onTap: _openNameSheet,
          ),
          _divider(),

          // 2. NIK
          _infoRow(
            icon: Icons.badge_outlined,
            label: t(context, 'nik'),
            value: _maskedNik,
            onTap: _openNikSheet,
          ),
          _divider(),

          // 3. Jenis Kelamin
          _infoRow(
            icon: Icons.wc_rounded,
            label: t(context, 'gender'),
            value: _gender ?? '-',
            onTap: _openGenderSheet,
          ),
          _divider(),

          // 4. Tanggal Lahir — tap → _pickDate() directly
          _infoRow(
            icon: Icons.calendar_month_rounded,
            label: t(context, 'birthDate'),
            value: _maskedBirthDate,
            onTap: _pickDate,
          ),
          _divider(),

          // 5. Alamat
          _infoRow(
            icon: Icons.location_on_outlined,
            label: t(context, 'address'),
            value: _addressPreview,
            onTap: _openAddressSheet,
          ),
          _divider(),

          // 6. Nomor Telepon — READ-ONLY, eye toggle
          _infoRow(
            icon: Icons.phone_iphone_rounded,
            label: t(context, 'phoneNumber'),
            value: _displayPhone,
            trailing: IconButton(
              icon: Icon(
                _hidePhone ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: _ink3,
              ),
              onPressed: () => setState(() => _hidePhone = !_hidePhone),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          _divider(),

          // 7. Email — READ-ONLY, masked
          _infoRow(
            icon: Icons.email_outlined,
            label: t(context, 'email'),
            value: _maskedEmail,
          ),
          _divider(),

          // 8. ID Pasien — READ-ONLY, copy icon
          _infoRow(
            icon: Icons.fingerprint_rounded,
            label: t(context, 'patientIdLabel'),
            value: _medicalCode,
            trailing: _medicalCode == '-'
                ? null
                : IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 20, color: _ink3),   // actually _ink3 — read-only tint
                    onPressed: _copyMedicalCode,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
          ),
        ]),

        // Loading indicator shown when _isLoading
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: CircularProgressIndicator(color: _c700, strokeWidth: 2),
          ),
      ],
    ),
  ),
  ```

  Remove the `Form(key: _formKey, onChanged: ...)` wrapper around the entire column — it is no longer needed at the top level since each sheet carries its own `GlobalKey<FormState>`. Keep `_formKey` as a field but it will only be used by `_save()` as-is (the global form is now just a no-op container; `_save()` calls `_formKey.currentState?.validate()` and should still work because no top-level `TextFormField`s register to it anymore — see note below).

  > **Note on `_save()` and `_formKey`:** `_save()` currently calls `if (!(_formKey.currentState?.validate() ?? false)) return;`. With the top-level `Form` removed, `_formKey.currentState` will be null and `validate()` returns false, blocking saves. Fix: change that guard to `if (_isLoading) return;` — the per-sheet validators already gate the fields before calling `_save()`. Remove the `_formKey` field entirely since it is no longer used anywhere. This is part of this step.

  Files: `lib/screens/home/edit_profile_screen.dart`  
  Verify: `flutter analyze lib/screens/home/edit_profile_screen.dart` — zero errors, zero warnings.

- [ ] 8. **Full build and hot-restart verification**  
  Run a debug build to confirm the screen compiles and renders correctly.  
  Files: none  
  Verify:
  ```
  flutter build apk --debug
  ```
  Expected: exits 0, no compilation errors.  
  Secondarily: `flutter analyze` on the whole project — no new errors introduced.

---

## Summary of helpers removed vs kept

| Helper | Fate | Reason |
|---|---|---|
| `_editableField()` | **Removed** | Replaced by `_infoRow()` + bottom sheets |
| `_genderPicker()` | **Removed** | Logic moved inside `_openGenderSheet()` |
| `_datePicker()` | **Removed** | Row tap calls `_pickDate()` directly |
| `_saveButton()` | **Removed** | Saving is per-sheet; no global save button |
| `_sectionTitle()` | **Removed** | New layout has no section headers |
| `_readOnlyField()` | **Removed** | Superseded by `_infoRow()` with `trailing:` |
| `_buildAppBar()` | Kept | No change needed |
| `_buildAvatar()` | **Removed** | Replaced by `_buildPhotoCard()` |
| `_buildCard()` | Kept | Still used for the info list card |
| `_divider()` | Kept | Still used between rows |
| `_infoRow()` | **New** | Unified row pattern (items 4 + 7) |
| `_buildPhotoCard()` | **New** | Photo upload card (item 3) |
| `_openNameSheet()` | **New** | |
| `_openNikSheet()` | **New** | |
| `_openGenderSheet()` | **New** | |
| `_openAddressSheet()` | **New** | |
| `_maskedName` getter | **New** | |
| `_maskedNik` getter | **New** | |
| `_maskedEmail` getter | **New** | |
| `_maskedBirthDate` getter | **New** | |
| `_addressPreview` getter | **New** | |

## Import changes

No new imports. All used types (`showModalBottomSheet`, `StatefulBuilder`, `GlobalKey<FormState>`, `FilteringTextInputFormatter`, `LengthLimitingTextInputFormatter`, `OutlinedButton`, `FilledButton`, `InkWell`, `Material`) are already available via `package:flutter/material.dart` and `package:flutter/services.dart`, both of which are already imported.
