# 🏥 Kedota Physiotherapy App

> **"Your Comfort, Our Care"** — Aplikasi layanan fisioterapi modern, aman, dan intuitif berbasis Flutter & Supabase.

---

## 📌 Status Proyek

| Fitur / Modul | Status | Keterangan |
| :--- | :---: | :--- |
| 🌐 Multi-Language (ID / EN) | 🟢 Selesai | Bahasa Indonesia & Inggris, toggle di Settings |
| 🚀 Onboarding Screen | 🟢 Selesai | Tampil sekali saat pertama buka, 3 slide interaktif |
| 🔑 Sign In via Nomor HP | 🟢 Selesai | OTP → PIN → Home |
| 📝 Registrasi via Nomor HP | 🟢 Selesai | OTP → Lengkapi Profil → Buat PIN → Akun Berhasil Dibuat |
| 🌐 Google Sign-In | 🟢 Selesai | OAuth Google → Pilih Akun → Lengkapi Profil → OTP → Buat PIN → Home |
| 🍎 Apple Sign-In | ⚪ Placeholder | UI tersedia, belum aktif |
| 📩 Verifikasi OTP Dummy | 🟢 Selesai | Kode valid: `123456`, `555555`, `000000`, `999999` |
| 🔓 Lupa PIN | 🟢 Selesai | OTP → Verifikasi Tanggal Lahir → PIN Baru (boleh sama dengan lama) |
| 🛡️ Rate Limiting | 🟢 Selesai | PIN salah 3x → kunci 5 menit, OTP salah 3x → cooldown 30 detik |
| 💤 Dormant Account | 🟢 Selesai | Akun >60 hari tidak aktif → verifikasi via email |
| 🎨 UI Consistency | 🟢 Selesai | Semua auth screen menggunakan layout header teal + white card bawah |
| ⚡ Edge Functions | 🟢 Selesai | Update PIN via server-side function (secure service-role key) |
| 🏠 Home Screen | ⏳ Dalam Pengembangan | Placeholder tersedia |
| 📅 Reservasi & Jadwal | ⏳ Dalam Pengembangan | — |
| 📋 Riwayat Medis | ⏳ Dalam Pengembangan | — |
| ⚙️ Settings | ⏳ Dalam Pengembangan | Termasuk language toggle & profil |

---

## ✨ Fitur Utama

### 1. 🚀 Onboarding
- 3 slide interaktif dengan animasi page transition
- Hanya muncul sekali saat pertama kali membuka aplikasi
- Status disimpan secara lokal menggunakan `SharedPreferences`
- Konten slide:
  1. **Pesan Jadwal Tanpa Ribet!** — Atur jadwal konsultasi dengan gampang dan efisien
  2. **Pantau Kesehatan Lebih Mudah** — Monitor perkembangan vital-mu secara real-time
  3. **Perawatan Medis Dirumah Anda** — Atur jadwal untuk melakukan perawatan medis dirumah

---

### 2. 🔑 Sign In & Registrasi via Nomor HP

**Alur nomor sudah terdaftar:**
```
Sign In → Input Nomor HP
  → OTP Verification (123456 / 555555 / 000000 / 999999)
  → PIN Verification (6-digit)
  → Home Screen
```

**Alur nomor belum terdaftar:**
```
Sign In → Input Nomor HP
  → OTP Verification
  → Lengkapi Profil (Nama, Email, Tanggal Lahir, Gender)
  → Buat PIN (6-digit) → Konfirmasi PIN
  → Account Created Screen (animasi ✓ + countdown 5 detik)
  → Home Screen
```

**Validasi nomor HP Indonesia:**
| Format Input | Contoh | Hasil Normalisasi |
|---|---|---|
| `08xxxxxxxxx` | `081234567890` | `+6281234567890` |
| `628xxxxxxxxx` | `6281234567890` | `+6281234567890` |
| `8xxxxxxxxx` | `81234567890` | `+6281234567890` |

**Error state visual:** Input nomor HP menampilkan border merah jika kosong atau format tidak valid, border hilang otomatis saat user mulai mengetik ulang.

**Session persisten:** Setelah login berhasil, saat app dibuka kembali langsung ke PIN Verification tanpa OTP ulang.

---

### 3. 🌐 Google Sign-In

**Alur akun baru:**
```
Sign In → Continue with Google
  → Pilih Akun Google (dialog picker selalu muncul)
  → Lengkapi Profil (nama auto-fill dari Google, nomor HP & TTL isi manual)
  → OTP Verification (verifikasi nomor HP yang diisi)
  → Buat PIN (6-digit) → Konfirmasi PIN
  → Account Created Screen
  → Home Screen
```

**Alur akun sudah terdaftar:**
```
Sign In → Continue with Google
  → Pilih Akun Google (dialog picker selalu muncul)
  → PIN Verification (langsung, tanpa OTP ulang)
  → Home Screen
```

**Edge case — email Google sama dengan akun HP:**
```
Sign In → Continue with Google
  → Deteksi signup_method == 'phone'
  → Sign out session Google
  → OTP Verification (verifikasi nomor HP terdaftar)
  → PIN Verification
  → Home Screen
```

**Routing logic (setelah OAuth callback):**
- `phone ada` && `pin_hash ada` → **PinVerificationScreen**
- Salah satu kosong → **GoogleProfileCompletionScreen**
- `signup_method == 'phone'` && `phone ada` → sign out → **OtpVerificationScreen**

---

### 4. 🔓 Lupa PIN

```
PIN Verification → Lupa PIN
  → Input Nomor HP          [layout: header teal + white card]
  → OTP Verification        [layout: header teal + white card]
  → Verifikasi Tanggal Lahir [layout: header teal + white card]
  → Buat PIN Baru           [layout: putih penuh + icon gembok + numpad]
  → Konfirmasi PIN          [layout: putih penuh + icon gembok + numpad]
      ↳ PIN tidak cocok → error inline merah (dots merah)
  → PIN Reset Success Screen (animasi ✓ + countdown 3 detik)
  → Sign In Screen
```

**Catatan:** PIN baru boleh sama dengan PIN lama — user sudah terverifikasi identitasnya via OTP + tanggal lahir.

---

### 5. 🛡️ Keamanan

| Mekanisme | Detail |
|---|---|
| PIN Hashing | SHA-256 (tersimpan di kolom `pin_hash`) |
| PIN Rate Limit | Salah 3x → layar kunci 5 menit |
| OTP Rate Limit | Salah 3x → redirect ke OTP Rate Limit Screen (cooldown 30 detik) |
| Google Account Picker | `signOut()` sebelum `signIn()` — dialog pilih akun selalu muncul |
| Profile Completeness Check | Hanya `phone` + `pin_hash` keduanya ada yang dianggap akun lengkap |
| Duplicate Phone Check | Cek nomor duplikat mengecualikan akun milik user yang sedang login |
| Duplicate Email Check | Cek email duplikat saat profil phone dibuat |
| Dormant Account | Tidak aktif >60 hari → verifikasi via email OTP |
| Edge Function | Update PIN untuk forgot PIN flow via server-side function (`update-pin`) |
| Service-Role Key | Hanya digunakan di Edge Function (server-side), tidak pernah di client |

---

### 6. 🎨 UI / UX

- **Layout auth utama**: Header teal dengan logo KEDOTA + white card rounded di bawah (Sign In, OTP, Lupa PIN, Verif Tanggal Lahir)
- **Layout PIN screen**: Putih penuh dengan icon gembok + step indicator + 6 dots + numpad (Create PIN, Verify PIN, Reset PIN)
- **Color scheme**: `#00A79D` (primary teal), `#1E293B` (text dark), `#E8F6F4` (background teal muda)
- **Error handling form**: Border merah pada input + `CustomBottomSheet` untuk pesan error
- **PIN error**: Inline dots merah untuk mismatch PIN
- **Success screens**: Animasi elastik icon centang + countdown otomatis
- **Haptic feedback**: Setiap tap angka pada numpad
- **Entrance animation**: Fade + slide + scale pada Sign In dan Lupa PIN screen

---

## 🗂️ Struktur Folder

```
lib/
├── l10n/
│   └── app_language.dart                    # Semua string ID & EN
├── screens/
│   ├── auth/
│   │   ├── account_created_screen.dart      # Sukses registrasi + countdown 5 detik
│   │   ├── forgot_pin_screen.dart           # Lupa PIN (4 screen dalam 1 file):
│   │   │                                    #   ForgotPinScreen (input no. telp)
│   │   │                                    #   BirthDateVerificationScreen (verif TTL)
│   │   │                                    #   ResetPinFormScreen (buat PIN baru)
│   │   │                                    #   PinResetSuccessScreen (sukses reset)
│   │   ├── google_create_pin_screen.dart    # Buat PIN setelah Google sign-in
│   │   ├── google_profile_completion_screen.dart  # Lengkapi profil akun Google baru
│   │   ├── otp_verification_screen.dart     # Verifikasi OTP 6-digit
│   │   ├── phone_create_pin_screen.dart     # Buat PIN setelah registrasi HP
│   │   ├── phone_profile_completion_screen.dart   # Lengkapi profil akun HP baru
│   │   ├── pin_verification_screen.dart     # Input PIN saat sign in
│   │   └── sign_in_screen.dart              # Entry point auth + Google/Apple OAuth
│   ├── errors/
│   │   ├── no_internet_screen.dart
│   │   ├── otp_rate_limit_screen.dart       # Cooldown 30 detik setelah OTP salah 3x
│   │   ├── pin_rate_limit_screen.dart       # Kunci 5 menit setelah PIN salah 3x
│   │   └── verification_rate_limit_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── onboarding/
│   │   └── onboarding_screen.dart
│   └── splash/
│       └── splash_screen.dart               # Auto-routing berdasarkan sesi & kelengkapan profil
├── services/
│   ├── supabase_auth_service.dart           # Semua logika autentikasi
│   ├── supabase_api_client.dart             # Retrofit API client (generated)
│   └── supabase_api_client.g.dart           # Generated code — jangan diedit manual
├── supabase/
│   ├── config.toml                          # Supabase project configuration
│   └── functions/
│       └── update-pin/
│           └── index.ts                     # Edge Function untuk update PIN (server-side)
└── widgets/
    ├── custom_bottom_sheet.dart             # Reusable bottom sheet (success/error/warning)
    ├── custom_error_screen.dart
    ├── google_logo_icon.dart
    └── language_button.dart
```

---

## 🛠️ Tech Stack

| Komponen | Teknologi |
|---|---|
| Framework | Flutter 3.x (Dart) |
| Backend | Supabase (PostgreSQL + Auth + Edge Functions) |
| OAuth | Google Sign-In via native SDK + Supabase |
| HTTP Client | Dio + Retrofit (generated) |
| Local Storage | `shared_preferences` |
| PIN Security | SHA-256 Hashing |
| Server Functions | Supabase Edge Functions (Deno runtime) |
| UI Style | Header teal + White card layout |

---

## 🚀 Cara Menjalankan

```bash
# 1. Clone repository
git clone https://github.com/username/kedotaapp.git
cd kedotaapp

# 2. Install dependencies
flutter pub get

# 3. Setup environment
# Salin .env.example → .env, isi SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY

# 4. Jalankan
flutter run
```

### Kredensial Testing

**OTP Dummy (6-digit):**
```
123456   555555   000000   999999
```

**Format nomor HP valid:**
```
081234567890
6281234567890
81234567890
```

---

## ⚡ Supabase Edge Functions

### Update PIN Function

Aplikasi ini menggunakan **Supabase Edge Function** untuk menangani update PIN secara aman, khususnya pada alur lupa PIN di mana user tidak memiliki session aktif.

**Mengapa Edge Function?**
- Service-role key **hanya** digunakan di server-side (aman)
- Client app tidak pernah mengekspos service-role key
- Validasi JWT token di server untuk keamanan ekstra
- Rollback otomatis jika terjadi error

**Arsitektur:**
```
┌────────────────────────────────────────────┐
│         Flutter App (Client)               │
│  • Tidak punya service-role key ✓          │
│  • Kirim request dengan JWT/anon key ✓     │
└────────────────────────────────────────────┘
                    │
                    │ HTTPS + JWT
                    ▼
┌────────────────────────────────────────────┐
│    Edge Function: update-pin (Server)      │
│  • Validasi JWT token ✓                    │
│  • Gunakan service-role key (aman) ✓       │
│  • Update profiles.pin_hash ✓              │
│  • Sync Supabase Auth password ✓           │
│  • Rollback jika gagal ✓                   │
└────────────────────────────────────────────┘
```

**Endpoint:**
```
POST https://wwmctqhbqpsbkyxkeaqv.supabase.co/functions/v1/update-pin
```

**Request:**
```json
{
  "profile_id": "uuid-user",
  "new_pin_hash": "sha256-hash",
  "new_pin": "123456"
}
```

**Response (Success):**
```json
{
  "success": true,
  "profile": { ... }
}
```

**Kapan Digunakan:**
1. **Lupa PIN flow** — User reset PIN tanpa session aktif
2. **Future: Admin operations** — Admin reset PIN user

**Deployment:**
```bash
# Login
supabase login

# Link project
supabase link --project-ref wwmctqhbqpsbkyxkeaqv

# Deploy function
supabase functions deploy update-pin
```

Lihat `DEPLOY_EDGE_FUNCTION.md` untuk panduan deployment lengkap.

---

## 🗃️ Supabase Database

### Tabel `profiles`

| Kolom | Tipe | Keterangan |
|---|---|---|
| `id` | uuid | Primary key, terhubung ke `auth.users` |
| `phone` | text | Nomor HP format `+62xxx` (dinormalisasi saat simpan) |
| `full_name` | text | Nama lengkap |
| `email` | text | Email display (dari input user atau Google) |
| `auth_email` | text | Email yang dipakai di Supabase Auth |
| `pin_hash` | text | SHA-256 hash dari PIN 6-digit |
| `birth_date` | date | Tanggal lahir format `YYYY-MM-DD` (untuk verifikasi lupa PIN) |
| `gender` | text | `Laki-laki` / `Perempuan` / `Lainnya` |
| `signup_method` | text | `phone` / `google` / `apple` |
| `is_profile_complete` | bool | Flag kelengkapan profil (informasi tambahan) |
| `last_login_at` | timestamptz | Untuk deteksi akun dormant (>60 hari) |
| `created_at` | timestamptz | — |
| `updated_at` | timestamptz | — |

### Logika Profile Completeness

Akun dianggap **lengkap** hanya jika kolom `phone` **dan** `pin_hash` keduanya tidak kosong di tabel `profiles`. Flag `is_profile_complete` digunakan sebagai informasi tambahan, bukan penentu utama routing.

### Auth Email Strategy

- **Phone signup**: menggunakan email asli user sebagai auth identity (jika valid), fallback ke `{digits}@kedota.local`
- **Google signup**: menggunakan email Google sebagai auth identity
- Penyimpanan ke `auth_email` memungkinkan sign-in multi-kandidat untuk menangani migrasi email

---

## 🔄 Alur Routing Splash Screen

```
App dibuka
  └─ SplashScreen (animasi ~2.85 detik)
       ├─ [session aktif]
       │    ├─ phone ada && pin_hash ada  →  PinVerificationScreen
       │    └─ salah satu kosong          →  GoogleProfileCompletionScreen
       ├─ [no session] && hasSeenOnboarding  →  SignInScreen
       └─ [no session] && belum onboarding   →  OnboardingScreen
```

---

## 🖼️ Layout Screen

| Screen | Layout |
|---|---|
| Splash | Background teal penuh + logo animasi zoom-out → white |
| Onboarding | Slide interaktif |
| Sign In | Header teal (logo KEDOTA) + white card bawah |
| OTP Verification | Header teal (logo KEDOTA) + white card bawah |
| PIN Verification | Putih penuh + icon gembok + numpad |
| Profil Completion (HP & Google) | Glassmorphism card dengan gradient background |
| Create PIN (HP & Google) | Putih penuh + icon gembok + numpad |
| Lupa PIN — Input No. Telp | Header teal (logo KEDOTA) + white card bawah |
| Lupa PIN — Verif OTP | Header teal (logo KEDOTA) + white card bawah (via OtpVerificationScreen) |
| Lupa PIN — Verif TTL | Header teal (logo KEDOTA) + white card bawah |
| Lupa PIN — Buat PIN Baru | Putih penuh + icon gembok + numpad |
| PIN Reset Success | Gradient background + animasi centang |
| Account Created | Gradient background + animasi centang |

---

*© 2026 Kedota Physiotherapy App. All Rights Reserved.*
