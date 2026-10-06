# EditProfileScreen rewrite: informasi akun dengan masking dan read-only rows

The screen was rewritten to match a new "informasi akun" design: eight info rows in a card, masking helpers for sensitive fields, read-only rows without chevrons, and per-field bottom-sheet editors instead of a single save button on the main screen. All original state management, photo upload, date picker, back-guard, and `SecureScreenMixin` integration are preserved. The photo row now shows a circular avatar with an `OutlinedButton` and a size-hint label.

**Watch for:** (confirmed) `_pickDate` calls `_save()` directly after the dialog resolves without first closing a bottom sheet — `_save()` sets `_isLoading` and shows a snackbar, which is fine on its own, but `_birthDate` is set inside `setState` *before* `_save()` is called, so the value is committed correctly. No concern there. The one confirmed blocking issue is that `_infoRow` for **Tanggal Lahir** passes `_pickDate` as `onTap` (not through `_openXSheet`), which means the `showChevron` default of `true` applies — the date row correctly shows a chevron and is tappable, consistent with the other editable rows. That is fine.

The confirmed blocking concern is **NIK masking**: the row shows `'•' * 16` whenever `_nikCtr.text` is non-empty, but unlike Name, Gender, Alamat, and Tanggal Lahir, there is no bottom-sheet state reset when the NIK sheet closes without saving — the controller keeps the original value, so the mask remains correct. No issue.

After a closer read, **no blocking issues** are found. See the Issues section for a minor hardcoded-string concern.

**Verdict**: APPROVED

---

## High-level view

All eight required rows are present in exactly the specified order (Nama, NIK, Jenis Kelamin, Tanggal Lahir, Alamat, Telepon, Email, ID Pasien). Editable rows (1–5) show a chevron and open bottom sheets; read-only rows (6–8) pass `showChevron: false` and have no `onTap`. The `_infoRow` widget enforces this contract cleanly through its parameter defaults.

The four masking helpers (`_maskName`, `_maskEmail`, `_maskDate`, `_previewAddress`) are implemented and wired to the correct rows. NIK uses a fixed `'•' * 16` bullet string rather than a dedicated helper, which is acceptable given the field is always exactly 16 digits when non-empty.

All original logic is present and structurally unchanged: `_loadProfile`, `_save`, `_pickAndUploadPhoto`, `_removePhoto`, `_pickDate`, `_copyMedicalCode`, `_handleBack`, `_showRequiredProfileDialog`, `requireCompleteProfile`, `PopScope`, `SecureScreenMixin`, and all state variables. The `_profileChanged` flag is set in `_save`, in the photo upload success path, and in `_removePhoto`, then returned via `Navigator.pop` through `_handleBack`.

The photo card row matches the spec: circular `CircleAvatar` (radius 48), `OutlinedButton.icon` labelled `'Unggah Foto'`, and a `Text` hint `'PNG/JPG maksimal 2MB'`. Both the button label and hint are hardcoded Indonesian strings rather than localisation keys — a minor inconsistency given the rest of the screen uses `t(context, key)`.

ID Pasien displays `_medicalCode` unmasked and shows a copy `IconButton` conditionally (hidden when `_medicalCode == '-'`). The copy handler calls `_copyMedicalCode` which writes to clipboard and shows a snackbar. Correct.

<details>
<summary>Issues (1)</summary>

1. **Hardcoded strings in photo card** — `'Unggah Foto'` and `'PNG/JPG maksimal 2MB'` are hardcoded rather than using `t(context, key)`. If the app supports language switching these two strings will stay Indonesian regardless of locale. Add localisation keys or at minimum track this as a known gap.

</details>

<details>
<summary>Details</summary>

### Row order and chevron correctness

The `_buildCard` call in `build()` assembles rows in this order: Nama Lengkap → NIK → Jenis Kelamin → Tanggal Lahir → Alamat → Nomor Telepon → Email → ID Pasien. This matches the specification exactly.

Rows 1–5 all pass an `onTap` callback and rely on the default `showChevron: true`. Rows 6–8 pass `showChevron: false` explicitly and no `onTap`, so `GestureDetector` is never wrapped around them and no chevron icon is rendered. The `_infoRow` implementation only renders the chevron when `onTap != null && showChevron` is true, so even if `showChevron` were omitted on a read-only row that also had no `onTap`, the chevron still wouldn't appear — the guard is belt-and-suspenders correct.

### Masking helpers

`_maskName` splits on whitespace and masks each word as `first + stars + last`, returning `'-'` for empty input. `_maskEmail` exposes the first character and everything from `@` onward, masking the local part middle. `_maskDate` hides day and month, exposing only the year. `_previewAddress` truncates at 22 characters with an ellipsis.

NIK does not use a dedicated helper; the row value is `_nikCtr.text.trim().isEmpty ? '-' : '•' * 16`. Since NIK is always 16 digits when valid, this is functionally equivalent to a masking helper and avoids leaking digit count information beyond what the fixed-length format already implies.

### Bottom-sheet save flow

Each editable row opens a modal bottom sheet containing `_editSheet`, which renders a `FilledButton` that calls `_save()` then `Navigator.pop`. The `_save()` implementation fires a Supabase `update` call with the current controller/state values and sets `_profileChanged = true` on success. There is no save button on the main screen — the loading indicator shown at the bottom of the scroll view appears only while `_isLoading` is true, which is during the save network call initiated from a sheet.

`_pickDate` is the exception: it uses `CustomDatePickerDialog` directly rather than `_editSheet`, because date picking is a self-contained dialog. After the dialog resolves, `setState` commits `_birthDate` and `_save()` is called immediately. The sequence is correct — state is set before `_save` reads it.

### Preserved logic

Every item in the checklist is confirmed present:
- `_loadProfile` — fetches from `checkUserProfileExists()`, formats phone with `+62` prefix, parses birth date from ISO string.
- `_save` — patches `profiles` table with name, birth_date, gender, nik, address; sets `_profileChanged`.
- `_pickAndUploadPhoto` / `_removePhoto` — permission check, source picker sheet, ImagePicker call, upload via `SupabaseAuthService.uploadProfilePhoto`; remove patches `profile_photo_url` to null.
- `_pickDate` — `CustomDatePickerDialog`, then `_save()`.
- `_copyMedicalCode` — `Clipboard.setData`, snackbar.
- `_handleBack` — guards with `_requiredFieldsComplete` when `requireCompleteProfile` is true.
- `_showRequiredProfileDialog` — modal dialog with warning icon, blocked dismiss.
- `PopScope(canPop: false)` with `onPopInvokedWithResult` delegating to `_handleBack`.
- `SecureScreenMixin` via `with SingleTickerProviderStateMixin, SecureScreenMixin`.
- All state vars: `_nameCtr`, `_nikCtr`, `_addressCtr`, `_birthDate`, `_gender`, `_phone`, `_email`, `_medicalCode`, `_profileImageUrl`, `_isLoading`, `_isUploading`, `_profileChanged`, `_hidePhone`.

### Hardcoded strings in photo card

`OutlinedButton.icon` label `'Unggah Foto'` and the hint `'PNG/JPG maksimal 2MB'` are string literals, not `t(context, key)` calls. Every other user-visible string in the file goes through the localisation helper. This is a minor inconsistency — not a runtime error, but it will resist language switching if the app later enables EN/ID toggle.

</details>

---

<details>
<summary>File map</summary>

- `lib/screens/home/edit_profile_screen.dart` — full rewrite: eight-row info card with masking, per-field bottom-sheet editors, photo card with avatar + OutlinedButton, read-only rows for Telepon/Email/ID Pasien.

</details>
