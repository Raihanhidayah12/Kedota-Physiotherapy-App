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
| 🛡️ Rate Limiting | 🟢 Selesai | PIN salah 3x → kunci 5 menit, OTP salah 3x → redirect |
| 💤 Dormant Account | 🟢 Selesai | Akun >60 hari tidak aktif → verifikasi via email |
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
  → Input Nomor HP
  → OTP Verification
  → Verifikasi Tanggal Lahir
  → Buat PIN Baru (boleh sama dengan PIN lama — user sudah terverifikasi identitasnya)
  → Konfirmasi PIN
      ↳ PIN tidak cocok → error inline merah (dots merah)
  → PIN Reset Success Screen (animasi ✓ + countdown 3 detik)
  → Sign In Screen
```

---

### 5. 🛡️ Keamanan

| Mekanisme | Detail |
|---|---|
| PIN Hashing | FNV-1a Hash (tersimpan di kolom `pin_hash`) |
| PIN Rate Limit | Salah 3x → layar kunci 5 menit |
| OTP Rate Limit | Salah 3x → redirect ke OTP Rate Limit Screen |
| Google Account Picker | `signOut()` sebelum `signIn()` — dialog pilih akun selalu muncul |
| Profile Completeness Check | Hanya `phone` + `pin_hash` keduanya ada yang dianggap akun lengkap |
| Duplicate Phone Check | Cek nomor duplikat mengecualikan akun milik user yang sedang login |
| Dormant Account | Tidak aktif >60 hari → verifikasi via email OTP |
| Admin PIN Update | `_updateProfileByAdmin` pakai Dio langsung dengan header `Prefer: return=representation` |

---

### 6. 🎨 UI / UX

- **Design style**: Glassmorphism dengan backdrop blur
- **Color scheme**: `#00A79D` (primary teal), `#17324D` (text dark)
- **Error handling**: Semua error form menggunakan `CustomBottomSheet` (konsisten di semua screen)
- **PIN error**: Inline dots merah khusus untuk mismatch PIN di screen PIN
- **Success screens**: Animasi elastik icon centang + countdown otomatis
- **Haptic feedback**: Setiap tap angka pada numpad

---

## 🗂️ Struktur Folder

```
lib/
├── l10n/
│   └── app_language.dart                    # Semua string ID & EN
├── screens/
│   ├── auth/
│   │   ├── account_created_screen.dart      # Sukses registrasi + countdown 5 detik
│   │   ├── forgot_pin_screen.dart           # Lupa PIN + verif tanggal lahir + reset PIN
│   │   ├── google_create_pin_screen.dart    # Buat PIN setelah Google sign-in
│   │   ├── google_profile_completion_screen.dart  # Lengkapi profil akun Google baru
│   │   ├── otp_verification_screen.dart     # Verifikasi OTP 6-digit
│   │   ├── phone_create_pin_screen.dart     # Buat PIN setelah registrasi HP
│   │   ├── phone_profile_completion_screen.dart   # Lengkapi profil akun HP baru
│   │   ├── pin_verification_screen.dart     # Input PIN saat sign in
│   │   └── sign_in_screen.dart              # Entry point auth + Google/Apple OAuth
│   ├── errors/
│   │   ├── no_internet_screen.dart
│   │   ├── otp_rate_limit_screen.dart
│   │   ├── pin_rate_limit_screen.dart
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
| Backend | Supabase (PostgreSQL + Auth + RLS) |
| OAuth | Google Sign-In via native SDK + Supabase |
| HTTP Client | Dio + Retrofit (generated) |
| Local Storage | `shared_preferences` |
| PIN Security | FNV-1a Hashing |
| UI Style | Glassmorphism + Custom Design System |

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

## 🗃️ Supabase Database

### Tabel `profiles`

| Kolom | Tipe | Keterangan |
|---|---|---|
| `id` | uuid | Primary key, terhubung ke `auth.users` |
| `phone` | text | Nomor HP format `+62xxx` (dinormalisasi saat simpan) |
| `full_name` | text | Nama lengkap |
| `email` | text | Email display |
| `auth_email` | text | Email yang dipakai di Supabase Auth |
| `pin_hash` | text | Hash PIN FNV-1a |
| `birth_date` | date | Tanggal lahir (untuk verifikasi lupa PIN) |
| `gender` | text | `Laki-laki` / `Perempuan` / `Lainnya` |
| `signup_method` | text | `phone` / `google` / `apple` |
| `is_profile_complete` | bool | Flag kelengkapan profil |
| `last_login_at` | timestamptz | Untuk deteksi akun dormant (>60 hari) |
| `created_at` | timestamptz | — |
| `updated_at` | timestamptz | — |

### Logika Profile Completeness

Akun dianggap **lengkap** hanya jika kolom `phone` **dan** `pin_hash` keduanya tidak kosong di tabel `profiles`. Flag `is_profile_complete` digunakan sebagai informasi tambahan, bukan penentu utama routing.

---

## 🔄 Alur Routing Splash Screen

```
App dibuka
  └─ SplashScreen
       ├─ [session aktif]
       │    ├─ phone ada && pin_hash ada  →  PinVerificationScreen
       │    └─ salah satu kosong          →  GoogleProfileCompletionScreen
       ├─ [no session] && hasSeenOnboarding  →  SignInScreen
       └─ [no session] && belum onboarding   →  OnboardingScreen
```

---

*© 2026 Kedota Physiotherapy App. All Rights Reserved.*
