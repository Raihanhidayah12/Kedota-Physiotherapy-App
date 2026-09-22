# Kedota Physiotherapy App

> **"Your Comfort, Our Care"** — Aplikasi layanan fisioterapi berbasis Flutter dan Supabase.

Kedota adalah aplikasi pasien untuk mengelola akun, membuat janji terapi, memantau progres, menerima pengingat, dan mengatur pembayaran. Aplikasi mendukung Android, iOS, dan Web melalui Flutter.

## Status Saat Ini

- Framework: Flutter dengan Dart SDK `^3.12.2`
- Backend: Supabase Auth, PostgreSQL, Storage, REST API, RPC, dan Edge Functions
- Bahasa UI: Bahasa Indonesia (default) dan English — seluruh string UI terlokalisasi penuh, tidak ada hardcoded text
- Peta & Geocoding: `flutter_map` (OpenStreetMap tile) + Geoapify API (geocoding akurat) dengan fallback Nominatim
- Pembayaran: alur UI dan RPC pelunasan tersedia; payment gateway masih demo
- Environment: URL dan publishable/anon key Supabase dibaca dari file `.env`
- Test otomatis: 27 unit/widget test lulus; OAuth production dan integration flow memerlukan device, backend, serta credential nyata

---

## 📌 Status Proyek

| Fitur / Modul | Status | Keterangan |
| :--- | :---: | :--- |
| 🌐 Multi-Language (ID / EN) | 🟢 Selesai | Paritas 100% ID & EN di seluruh aplikasi — tidak ada hardcoded string di UI |
| 🧪 Auth Flow Tests | 🟢 Selesai | Test widget untuk Onboarding, Sign In, Forgot PIN/OTP, sign-up phone, Google profile, dan pembuatan PIN |
| 🚀 Onboarding Screen | 🟢 Selesai | Tampil sekali saat pertama buka, 3 slide interaktif (`SharedPreferences`) |
| 🔑 Sign In via Nomor HP | 🟢 Selesai | OTP → PIN → Home Screen |
| 📝 Registrasi via Nomor HP | 🟢 Selesai | OTP → Lengkapi Profil → Buat PIN → Account Created Screen |
| 🌐 Google Sign-In | 🟢 Selesai | OAuth Google → Picker Akun → Lengkapi Profil / Direct PIN → Home |
| 🍎 Apple Sign-In | 🟢 Selesai | OAuth Apple terintegrasi (`signInWithOAuth`) |
| 📩 OTP Verifikasi | 🟢 Selesai | Dummy codes: `123456`, `555555`, `000000`, `999999` |
| 📡 OTP Production (Plan) | 🔵 Siap Migrasi | Endpoint `/auth/otp` & `/auth/verify` disiapkan di Swagger |
| 🔓 Lupa PIN | 🟢 Selesai | OTP → Verifikasi Tanggal Lahir → PIN Baru → PIN Reset Success |
| 🔑 Ganti PIN (Settings) | 🟢 Selesai | Verifikasi PIN Lama → Input PIN Baru → Konfirmasi PIN Baru (Rate limit 3x) |
| 👤 Edit Profil | 🟢 Selesai | Ubah Nama, TTL, Gender, Upload/Hapus Foto Profil Supabase Storage |
| 👁️ Privasi Nomor HP | 🟢 Selesai | Default hidden (`+628••••9436`) + Eye Icon toggle di Settings & Edit Profile |
| 🔔 Preferensi Notifikasi | 🟢 Selesai | Push notif, reminder, notifikasi DP/expired, dan deep-link ke detail atau pelunasan |
| 🕒 Urutan & Waktu Notifikasi | 🟢 Selesai | Notifikasi terbaru tampil paling atas dengan waktu relatif |
| ⚙️ Settings & Akun | 🟢 Selesai | Pengaturan Lengkap + Hapus Akun Permanen (Verifikasi PIN 6-digit) |
| 🛡️ Rate Limiting | 🟢 Selesai | PIN salah 3x → kunci 5 menit, OTP salah 3x → cooldown 30 detik |
| 💤 Dormant Account | 🟢 Selesai | Deteksi akun >60 hari tidak aktif → verifikasi via email |
| 🎨 UI & Layout Stability | 🟢 Selesai | Responsive 0 overflow di mobile/web |
| ⚡ Edge Functions | 🟢 Selesai | Update PIN via server-side function (`update-pin` Deno runtime) |
| 📊 HTTP 5xx Error Logging | 🟢 Selesai | Deteksi & log metadata error HTTP 5xx ke Edge Function `client-error-log` |
| 📑 Legal Documents UI | 🟢 Selesai | Syarat & Ketentuan dan Kebijakan Privasi menggunakan accordion |
| 🏠 Home & Main Navigation | 🟢 Selesai | Main Screen dengan 4 tab: Beranda, Progress, Janji Temu, dan Profil |
| 📅 Reservasi Step-by-Step | 🟢 Selesai | Step 3 baru: Pilih Kota → Pilih Layanan → Jadwal → Jam → Alamat (berurutan, wajib diisi) |
| 🗺️ Peta Interaktif (Home Care) | 🟢 Selesai | `flutter_map` + Geoapify tile + reverse geocoding akurat; tap peta, gunakan lokasi terkini, ketik alamat → peta sync |
| 🔄 Reschedule | 🟢 Selesai | Screen modern untuk ubah tanggal/jam, validasi slot, dan reminder baru |
| 💳 DP & Pelunasan | 🟢 Selesai (Demo Gateway) | Card appointment tampilkan 2 tombol (Lihat Detail + Lunaskan) saat DP belum lunas |
| 🧾 Identitas Pasien & Booking | 🟢 Selesai | `medical_code` format `KDT-` + 12 karakter; `booking_code` format `EMR-` |
| ⏱️ Auto Expire | 🟢 Selesai | Janji `expired` 15 menit setelah waktu mulai |
| 🔒 Proteksi Slot | 🟢 Selesai | Unique index mencegah dua janji aktif di slot yang sama |
| 📋 Detail Riwayat Done | 🟢 Selesai | Tampilkan catatan klinis, skor progres (VAS/ROM/MMT/ODI), dan rekomendasi terapis dari DB |
| 🚫 DP Hangus & No-Show | 🟢 Selesai | DP belum lunas hangus saat tidak hadir; pembayaran lunas dapat reschedule maks 24 jam |

---

## ✨ Fitur Utama

### 1. 🚀 Onboarding
- 3 slide interaktif dengan animasi page transition.
- Hanya muncul sekali saat pertama kali membuka aplikasi.
- Status disimpan secara lokal menggunakan `SharedPreferences`.

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

---

### 3. 🌐 Google & Apple Sign-In

**Alur akun baru:**
```
Sign In → Continue with Google
  → Dialog Pilih Akun Google (always prompt)
  → Lengkapi Profil → OTP Verification → Buat PIN → Home Screen
```

**Alur akun terdaftar:**
```
Sign In → Continue with Google → PIN Verification → Home Screen
```

---

### 4. ⚙️ Pengaturan, Edit Profil & Keamanan Akun

- **Edit Profil**: Nama, TTL, Gender, Upload/Hapus Foto ke Supabase Storage.
- **Privasi Nomor HP**: Toggle hide/show nomor HP di Settings & Edit Profile.
- **Ganti PIN**: Verifikasi lama → PIN baru → Konfirmasi.
- **Preferensi Notifikasi**: Push, reminder jadwal, promo, berita email.
- **Hapus Akun Permanen**: Konfirmasi + verifikasi PIN 6-digit.

---

### 5. 🌐 Multi-Language Support (ID / EN)

- Default **Bahasa Indonesia** untuk semua pengguna baru.
- Seluruh string UI, dialog, SnackBar, hint, nama bulan, hingga label teknis terlokalisasi — **tidak ada hardcoded text di UI**.
- Toggle bahasa di Settings tanpa restart aplikasi (`AppLanguageScope`).
- Bahasa tersimpan **per device** di `SharedPreferences` — tidak direset saat logout, sehingga preferensi bahasa tetap berlaku untuk semua akun yang login di device yang sama.

**Cakupan lokalisasi yang difix:**

| File | String yang difix |
|---|---|
| `sign_in_screen.dart` | Greeting, country code `+62`, hint nomor HP, label Google & Apple |
| `forgot_pin_screen.dart` | Country code `+62` |
| `edit_profile_screen.dart` | Gender constants (`Laki-laki`/`Perempuan`) |
| `home_screen.dart` | 4 spesialisasi terapis dummy |
| `reservation_flow_screen.dart` | Kalimat deadline pembayaran, step counter, nama kota Home Care |
| `settle_payment_screen.dart` | Prefix mata uang `Rp`, pesan error generik |
| `history_screen.dart` | Fallback nama terapis, tipe layanan, dan waktu |

---

### 6. 📅 Reservasi Jadwal & Layanan (Step 3 — Baru)

Flow step 3 menggunakan urutan berurutan yang **wajib diisi secara berurutan** sebelum lanjut:

```
1. Pilih Kota         → dropdown (Malang, Surabaya, Sidoarjo, Surakarta, Yogyakarta)
2. Pilih Layanan      → Malang: Klinik atau Home Care | Kota lain: Home Care saja
3. Pilih Jadwal       → terbuka setelah layanan dipilih
4. Pilih Jam          → terbuka setelah tanggal dipilih
5. Alamat / Lokasi    → Home Care: field + peta interaktif | Klinik: info lokasi + peta
```

Field yang belum bisa diisi ditampilkan abu-abu dengan ikon 🔒 dan teks keterangan.

**Khusus Malang:** tersedia pilihan Klinik **dan** Home Care. Kota lain hanya Home Care.

---

### 7. 🗺️ Peta Interaktif (Home Care)

- Tile peta: **Geoapify** (`osm-bright` style) — lebih detail dari OpenStreetMap standar.
- **Geocoding akurat** menggunakan Geoapify API (3000 req/hari gratis) dengan fallback otomatis ke Nominatim lalu `geocoding` package.
- **Reverse geocoding** (koordinat → alamat lengkap): tap di peta atau gunakan lokasi terkini → field Alamat terisi otomatis dengan format `Jalan, Kelurahan, Kecamatan, Kota, Provinsi, Kode Pos`.
- **Forward geocoding** (ketik alamat → pindah peta): debounce 900ms setelah berhenti ketik → peta dan marker sync ke lokasi.
- **Popup peta** (fullscreen): tampil floating label alamat di atas peta, field detail di bawah, tombol ✕ untuk confirm & tutup.
- **Gunakan Lokasi Terkini**: `LocationAccuracy.bestForNavigation` untuk akurasi GPS tertinggi.

**Fallback chain geocoding:**
```
Geoapify API (akurat, 3000/hari)
    ↓ quota habis / error
Nominatim OpenStreetMap (gratis unlimited)
    ↓ error
geocoding package (butuh Google Play Services)
```

---

### 8. 💳 Pembayaran DP & Pelunasan

- Card appointment menampilkan **2 tombol** saat DP belum lunas: "Lihat Detail" (outline) + "Lunaskan Pembayaran" (solid).
- Saat DP lunas atau hangus: hanya tombol "Lihat Detail".
- Metode pembayaran: QRIS, OVO, GoPay, ShopeePay, BCA, BNI, BRI, Permata, Mandiri, kartu, tunai.
- Pelunasan menggunakan RPC `settle_appointment_payment`.
- Setelah berhasil: screen sukses countdown 3 detik → tab History.
- Pembayaran masih demo sampai payment gateway/webhook diterapkan.

---

### 9. 📋 Detail Riwayat — Status Done

Appointment yang sudah selesai (`completed`) menampilkan data klinis nyata dari DB:

| Field DB | Tampilan |
|---|---|
| `clinical_note` | Catatan klinis pasca sesi (collapsible, tap untuk baca penuh) |
| `vas_score` | Skala Nyeri VAS dengan persentase perbaikan |
| `rom_score` | Range of Motion dengan persentase |
| `mmt_score` | Kekuatan Otot MMT dengan persentase |
| `odi_score` | Oswestry Disability Index dengan persentase |
| `therapist_recommendation` | Banner kuning rekomendasi terapis |
| `therapist_sipf` | Nomor lisensi terapis |
| `therapist_photo_url` | Foto avatar terapis |

Kolom-kolom di atas perlu ditambahkan ke tabel `appointments` di Supabase. Selama kosong, tampilan fallback ke teks placeholder dari localization.

---

### 10. 🔔 Notifikasi In-App

- Terbaru tampil paling atas berdasarkan `created_at`.
- Waktu relatif: `Baru saja`, `2 menit yang lalu`, `3 jam yang lalu`, `Kemarin`.
- Label tersedia dalam ID & EN.

### 11. 📑 Syarat, Ketentuan & Kebijakan Privasi

- UI accordion — setiap section buka/tutup.
- Tanggal `Terakhir diperbarui` mengikuti tanggal perangkat.

### 12. 📊 Logging Error HTTP 5xx

- Global error handler aktif sejak app dibuka.
- Mendeteksi response `500-599` dari semua jalur: Dio, Supabase Auth, DB, Storage, RPC.
- Metadata aman dikirim ke Edge Function `client-error-log` secara background.
- Data tersimpan permanen di tabel `error_logs`.
- Dokumentasi: [`docs/5xx-error-logging.md`](docs/5xx-error-logging.md)

### 13. 🔓 Lupa PIN Flow

```
PIN Verification → Lupa PIN
  → Input Nomor HP → OTP Verification → Verifikasi Tanggal Lahir
  → Buat PIN Baru → Konfirmasi PIN
  → PIN Reset Success Screen (animasi ✓ + countdown 3 detik)
  → Sign In Screen
```

---

### 14. 🛡️ Keamanan & Stabilitas

| Mekanisme | Detail |
|---|---|
| PIN Hashing | SHA-256 (kolom `pin_hash`) |
| PIN Rate Limit | Salah 3x → kunci 5 menit |
| OTP Rate Limit | Salah 3x → cooldown 30 detik |
| Layout Stability | `SingleChildScrollView` + `ConstrainedBox` mencegah overflow |
| Google Account Picker | `signOut()` sebelum `signIn()` — dialog selalu muncul |
| Service-Role Key | Hanya di Edge Function, tidak pernah di client |

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

## 🖼️ Tampilan Layout Screen

| Screen | Layout Style |
|---|---|
| Splash | Background teal penuh + logo animasi zoom-out → white |
| Onboarding | Slide interaktif |
| Sign In | Header teal (logo KEDOTA) + white card bawah |
| OTP Verification | Header teal (logo KEDOTA) + white card bawah |
| PIN Verification | Putih penuh + icon gembok + numpad |
| Profil Completion | Glassmorphism card dengan gradient background |
| Create PIN | Putih penuh + icon gembok + numpad |
| Lupa PIN | Header teal (logo KEDOTA) + white card bawah |
| Edit Profil | White card layout + avatar gradient + dialogs |
| Settings | Header gradient teal + profile card + menu list |
| Reservasi Step 3 | Flat tanpa card — field berurutan + peta interaktif |
| Detail Riwayat Done | Card data klinis + grid progres 2×2 + banner rekomendasi |

---

## ⚡ Supabase Edge Functions

### Update PIN Function (`update-pin`)

```
Flutter App (Client)          Edge Function: update-pin (Server)
  • Tidak punya service-role  →  • Validasi JWT token
  • Kirim JWT/anon key           • Gunakan service-role key (aman)
                                 • Update profiles.pin_hash
                                 • Sync Supabase Auth password
                                 • Rollback jika gagal
```

**Deployment:**
```bash
supabase login
supabase link --project-ref wwmctqhbqpsbkyxkeaqv
supabase functions deploy update-pin
supabase functions deploy client-error-log
```

---

## 🗃️ Schema Supabase Database

### Tabel `appointments`

| Kolom | Tipe | Keterangan |
|---|---|---|
| `id` | uuid | Primary key |
| `booker_id` | uuid | FK ke `auth.users` |
| `service_type` | text | `Klinik` atau `Home Care` |
| `clinic_name` | text | Nama klinik/lokasi |
| `appointment_date` | date | Tanggal pertemuan |
| `appointment_time` | time | Jam pertemuan |
| `session_count` | integer | Jumlah sesi dalam paket |
| `appointment_status` | text | `upcoming`, `completed`, `expired`, `cancelled` |
| `payment_plan` | text | `full` atau `deposit` |
| `payment_status` | text | `paid`, `pending`, `failed`, `expired` |
| `amount_due` | numeric | Sisa pembayaran |
| `booking_code` | text | Format `EMR-####-########` |
| `clinical_note` | text | *(opsional)* Catatan klinis terapis pasca sesi |
| `vas_score` | integer | *(opsional)* Skala nyeri VAS (0-10) |
| `rom_score` | integer | *(opsional)* Range of Motion (0-120°) |
| `mmt_score` | integer | *(opsional)* Kekuatan otot MMT (0-5) |
| `odi_score` | integer | *(opsional)* Oswestry Disability Index (0-50) |
| `therapist_recommendation` | text | *(opsional)* Rekomendasi terapis |
| `therapist_sipf` | text | *(opsional)* Nomor lisensi terapis |
| `therapist_photo_url` | text | *(opsional)* URL foto terapis |
| `created_at` / `updated_at` | timestamptz | Timestamp |

### Tabel `profiles`

| Kolom | Tipe | Keterangan |
|---|---|---|
| `id` | uuid | PK, FK ke `auth.users` |
| `phone` | text | Format `+62xxx` |
| `full_name` | text | Nama lengkap |
| `email` | text | Email display |
| `auth_email` | text | Email identitas Supabase Auth |
| `pin_hash` | text | SHA-256 dari PIN 6-digit |
| `birth_date` | date | Format `YYYY-MM-DD` |
| `gender` | text | `Laki-laki` / `Perempuan` / `Lainnya` |
| `profile_photo_url` | text | URL foto dari Supabase Storage |
| `nik` | text | NIK 16 digit |
| `address` | text | Alamat untuk reservasi |
| `signup_method` | text | `phone` / `google` / `apple` |
| `status` | text | `active` / `deactivated` / `recycled` |
| `medical_code` | text | Format `KDT-` + 12 karakter acak unik |
| `last_login_at` | timestamptz | Deteksi akun dormant (>60 hari) |
| `created_at` / `updated_at` | timestamptz | Timestamp |

---

## 🛠️ Tech Stack

| Komponen | Teknologi |
|---|---|
| Framework | Flutter 3.x (Dart SDK `^3.12.2`) |
| Backend | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| OAuth | Google Sign-In & Apple Sign-In (OAuth) |
| HTTP Client | Dio + Retrofit (generated) |
| Peta | `flutter_map` v8 + Geoapify tile & geocoding |
| Lokasi | `geolocator` + `geocoding` (fallback) |
| Local Storage | `shared_preferences` |
| Security | SHA-256 PIN Hashing + Phone Masking |
| Server Functions | Supabase Edge Functions (Deno Runtime) |
| Multi-Language | `AppLanguageScope` (Indonesia default + English) |
| Observability | Dio interceptor + Flutter error handler + `client-error-log` Edge Function |
| API Spec | OpenAPI 3.0 — `swagger_supabase_api_spec.txt` |

---

## 🗂️ Struktur Folder

```
lib/
├── l10n/
│   └── app_language.dart                    # Kamus terjemahan ID & EN — tidak ada hardcoded text
├── screens/
│   ├── auth/
│   │   ├── account_created_screen.dart
│   │   ├── forgot_pin_screen.dart
│   │   ├── google_create_pin_screen.dart
│   │   ├── google_profile_completion_screen.dart
│   │   ├── otp_verification_screen.dart
│   │   ├── phone_create_pin_screen.dart
│   │   ├── phone_profile_completion_screen.dart
│   │   ├── pin_verification_screen.dart
│   │   └── sign_in_screen.dart
│   ├── errors/
│   │   ├── no_internet_screen.dart
│   │   ├── otp_rate_limit_screen.dart
│   │   ├── pin_rate_limit_screen.dart
│   │   └── verification_rate_limit_screen.dart
│   ├── home/
│   │   ├── appointment_detail_screen.dart   # Detail janji — data klinis, progres, rekomendasi
│   │   ├── change_pin_screen.dart
│   │   ├── edit_profile_screen.dart
│   │   ├── history_screen.dart              # AppointmentItem model + riwayat
│   │   ├── home_screen.dart
│   │   ├── main_screen.dart                 # Bottom nav 4 tab
│   │   ├── notification_preferences_screen.dart
│   │   ├── notification_screen.dart
│   │   ├── reservation_flow_screen.dart     # Alur reservasi 6 step + peta Geoapify
│   │   ├── reschedule_appointment_screen.dart
│   │   ├── settle_payment_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── support_info_screens.dart
│   │   └── upcoming_appointment_card.dart   # Card dengan 2 tombol saat DP belum lunas
│   ├── onboarding/
│   │   └── onboarding_screen.dart
│   └── splash/
│       └── splash_screen.dart
├── services/
│   ├── client_error_log_service.dart
│   ├── supabase_auth_service.dart
│   ├── notification_service.dart
│   ├── supabase_api_client.dart
│   └── supabase_api_client.g.dart
├── widgets/
│   ├── app_lock_overlay.dart
│   ├── custom_bottom_sheet.dart
│   ├── custom_date_picker.dart
│   ├── custom_error_screen.dart
│   ├── google_logo_icon.dart
│   ├── language_button.dart
│   └── data_error_widget.dart
└── utils/
    ├── app_snackbar.dart
    ├── booking_code.dart
    └── phone_validator.dart
```

---

## 🧪 Testing

Test widget dan unit tersedia untuk:

- Splash dan branding aplikasi
- Validasi nomor telepon
- Service hashing PIN
- Sign In phone dan validasi input
- Onboarding, skip, dan penyimpanan `has_seen_onboarding`
- Forgot PIN, validasi nomor, dan OTP dummy
- Sign-up phone: profile completion dan create PIN
- Google sign-up: profile completion dan create PIN

```bash
flutter test   # 27 test lulus
```

Integration test di `integration_test/app_test.dart` membutuhkan device Android/iOS, `.env`, dan koneksi Supabase.

---

## 🚀 Cara Menjalankan

```bash
# 1. Clone repository
git clone https://github.com/Raihanhidayah12/Kedota-Physiotherapy-App.git
cd Kedota-Physiotherapy-App

# 2. Siapkan environment
Copy-Item .env.example .env   # Windows PowerShell
# Isi SUPABASE_URL dan SUPABASE_ANON_KEY

# 3. Install dependencies
flutter pub get

# 4. Jalankan aplikasi
flutter run

# 5. Test
flutter test

# 6. Deploy Edge Functions
supabase login
supabase link --project-ref wwmctqhbqpsbkyxkeaqv
supabase functions deploy update-pin
supabase functions deploy client-error-log
supabase db push
```

> Jangan commit `.env`. Service-role key hanya boleh digunakan oleh Edge Function.

### Supabase Lokal

```bash
supabase start
supabase functions serve update-pin
supabase functions serve client-error-log
```

---

## 🗒️ Catatan Migrasi DB

Untuk mengaktifkan fitur Detail Riwayat Done dengan data klinis nyata, tambahkan kolom berikut ke tabel `appointments`:

```sql
ALTER TABLE appointments
  ADD COLUMN IF NOT EXISTS clinical_note TEXT,
  ADD COLUMN IF NOT EXISTS vas_score INTEGER,
  ADD COLUMN IF NOT EXISTS rom_score INTEGER,
  ADD COLUMN IF NOT EXISTS mmt_score INTEGER,
  ADD COLUMN IF NOT EXISTS odi_score INTEGER,
  ADD COLUMN IF NOT EXISTS therapist_recommendation TEXT,
  ADD COLUMN IF NOT EXISTS therapist_sipf TEXT,
  ADD COLUMN IF NOT EXISTS therapist_photo_url TEXT;
```

---

*© 2026 Kedota Physiotherapy App. All Rights Reserved.*
