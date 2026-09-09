# 🏥 Kedota Physiotherapy App

> **"Your Comfort, Our Care"** — Aplikasi layanan fisioterapi modern, aman, dan intuitif berbasis Flutter & Supabase.

---

## 📌 Status Proyek

| Fitur / Modul | Status | Keterangan |
| :--- | :---: | :--- |
| 🌐 Multi-Language (ID / EN) | 🟢 Selesai | Paritas 100% ID & EN di Auth, OTP, Edit Profile, Notifikasi, Settings & Forgot PIN (`AppLanguageScope`) |
| 🚀 Onboarding Screen | 🟢 Selesai | Tampil sekali saat pertama buka, 3 slide interaktif (`SharedPreferences`) |
| 🔑 Sign In via Nomor HP | 🟢 Selesai | OTP → PIN → Home Screen (Handled 400 pre-check & 422 password sync gracefully) |
| 📝 Registrasi via Nomor HP | 🟢 Selesai | OTP → Lengkapi Profil → Buat PIN → Account Created Screen |
| 🌐 Google Sign-In | 🟢 Selesai | OAuth Google → Picker Akun → Lengkapi Profil / Direct PIN → Home |
| 🍎 Apple Sign-In | 🟢 Selesai | OAuth Apple terintegrasi (`signInWithOAuth`) |
| 📩 OTP Verifikasi | 🟢 Selesai | Teks & Dialog terverifikasi dinamis (ID/EN), Dummy codes: `123456`, `555555`, `000000`, `999999` |
| 📡 OTP Production (Plan) | 🔵 Siap Migrasi | Endpoint `/auth/otp` & `/auth/verify` disiapkan di Swagger |
| 🔓 Lupa PIN | 🟢 Selesai | OTP → Verifikasi Tanggal Lahir → PIN Baru → PIN Reset Success |
| 🔑 Ganti PIN (Settings) | 🟢 Selesai | Verifikasi PIN Lama → Input PIN Baru → Konfirmasi PIN Baru (Rate limit 3x) |
| 👤 Edit Profil | 🟢 Selesai | Ubah Nama, TTL, Gender, Upload/Hapus Foto Profil Supabase Storage |
| 👁️ Privasi Nomor HP | 🟢 Selesai | Default hidden (`+628••••9436`) + Eye Icon toggle di Settings & Edit Profile |
| 🔔 Preferensi Notifikasi | 🟢 Selesai | Push notif, reminder 1 jam sebelum janji, notifikasi DP/expired, dan deep-link ke detail atau pelunasan |
| ⚙️ Settings & Akun | 🟢 Selesai | Pengaturan Lengkap + Hapus Akun Permanen (Verifikasi PIN 6-digit) |
| 🛡️ Rate Limiting | 🟢 Selesai | PIN salah 3x → kunci 5 menit, OTP salah 3x → cooldown 30 detik |
| 💤 Dormant Account | 🟢 Selesai | Deteksi akun >60 hari tidak aktif → verifikasi via email |
| 🎨 UI & Layout Stability | 🟢 Selesai | Numpad, DatePicker & Flex Badge responsive 0 overflow di mobile/web |
| ⚡ Edge Functions | 🟢 Selesai | Update PIN via server-side function (`update-pin` Deno runtime) |
| 🏠 Home & Main Navigation | 🟢 Selesai | Main Screen dengan 4 tab: Beranda, Progress, Janji Temu, dan Profil |
| 📅 Reservasi & Paket Sesi | 🟢 Selesai | Paket 1, 3, 6, atau 9 sesi dengan harga paket tetap |
| 🔄 Reschedule | 🟢 Selesai | Screen modern untuk ubah tanggal/jam, notifikasi perubahan, dan reminder baru |
| 💳 DP & Pelunasan | 🟢 Selesai (Demo Gateway) | Instruksi pembayaran, konfirmasi, screen sukses, redirect History 3 detik, dan RPC pelunasan |
| 🧾 Identitas Pasien & Booking | 🟢 Selesai | `medical_code` sebagai ID pasien tetap dan `booking_code` unik berurutan untuk setiap reservasi |
| ⏱️ Auto Expire | 🟢 Selesai | Janji berubah menjadi `expired` 15 menit setelah waktu mulai dan mengirim push ke pengguna |
| 🔒 Proteksi Slot | 🟢 Selesai | Unique index mencegah dua janji aktif memakai slot yang sama |

---

## ✨ Fitur Utama

### 1. 🚀 Onboarding
- 3 slide interaktif dengan animasi page transition.
- Hanya muncul sekali saat pertama kali membuka aplikasi.
- Status disimpan secara lokal menggunakan `SharedPreferences`.
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

---

### 3. 🌐 Google & Apple Sign-In

**Alur akun baru:**
```
Sign In → Continue with Google
  → Dialog Pilih Akun Google (always prompt)
  → Lengkapi Profil (Nama auto-fill, No. HP & TTL isi manual)
  → OTP Verification (verifikasi nomor HP yang diisi)
  → Buat PIN (6-digit) → Konfirmasi PIN
  → Account Created Screen → Home Screen
```

**Alur akun terdaftar:**
```
Sign In → Continue with Google
  → Dialog Pilih Akun Google
  → PIN Verification → Home Screen
```

---

### 4. ⚙️ Pengaturan, Edit Profil & Keamanan Akun

- **Edit Profil**:
  - Ubah Nama Lengkap, Tanggal Lahir (Date Picker + nama bulan dinamis ID/EN), dan Gender.
  - Upload dan Hapus Foto Profil terintegrasi dengan **Supabase Storage**.
- **Privasi Nomor HP (Hide/Show Phone)**:
  - Tombol icon mata (`Icons.visibility` / `Icons.visibility_off`) pada header **Settings** dan **Edit Profile** untuk menyembunyikan nomor HP (misal `+628••••9436`) demi menjaga kerahasiaan.
- **Ganti PIN (Change PIN)**:
  - Verifikasi PIN lama (rate limit 3x) → Buat PIN Baru → Konfirmasi PIN Baru.
- **Preferensi Notifikasi**:
  - Push Notifications, Pengingat Jadwal Terapi (H-1 & 2 jam sebelum sesi), Promo & Penawaran, serta Update Berita via Email.
- **Hapus Akun Permanen**:
  - Dialog konfirmasi bahaya + Verifikasi PIN 6-digit sebelum akun dan data dihapus permanen dari Supabase.

---

### 5. 🌐 Multi-Language Support (ID / EN)

- Mendukung **Bahasa Indonesia (ID)** dan **English (EN)** secara penuh di seluruh aplikasi.
- Toggle bahasa cepat di halaman Settings.
- Seluruh teks UI, dialog, Toast/SnackBar, hint input, hingga nama bulan pada DatePicker terjemah secara otomatis tanpa perlu restart aplikasi (`AppLanguageScope`).

---

### 6. 📅 Reservasi, Paket Sesi & Janji Temu

- Pilihan paket terapi:
  - 1 sesi — Rp225.000
  - 3 sesi — Rp660.000
  - 6 sesi — Rp1.290.000
  - 9 sesi — Rp1.890.000
- Setiap record `appointments` merepresentasikan satu jadwal pertemuan.
- `session_count` menyimpan jumlah sesi dalam paket dan dipakai untuk menghitung Progress.
- Slot divalidasi berdasarkan tanggal, jam, layanan, dan lokasi.
- Slot lama terbuka kembali setelah reschedule, sedangkan slot baru dikunci oleh unique index database.
- Screen reschedule terpisah memakai kalender custom dan pemilih jam yang sama dengan reservasi utama.
- Janji yang belum selesai otomatis menjadi `expired` setelah 15 menit dari waktu mulai ketika data dimuat.
- Setiap pasien memiliki `medical_code` tetap berformat `KED-` + 12 karakter acak heksadesimal, yang ditampilkan sebagai **ID Pasien** di profil.
- Setiap reservasi memiliki `booking_code` unik berurutan, dimulai dari `KDT-2026000001`.
- Tab Janji Temu dan Beranda menampilkan penanda merah untuk appointment dengan DP yang belum lunas.
- Screen Atur Jadwal Ulang memakai date picker dan time picker dengan validasi slot tersedia.
- Saat reschedule, reminder lama dibatalkan dan reminder baru dijadwalkan ulang.
- Teks UI terbaru, pesan WhatsApp CS, dan metode pembayaran mengikuti localization ID/EN.

### 7. 💳 Pembayaran DP & Pelunasan

- Reservasi penuh menyimpan `payment_status = paid`.
- Reservasi DP menyimpan `payment_status = pending` dan `amount_due` sebagai sisa pembayaran.
- Detail janji, Beranda, dan tab Janji Temu menampilkan badge merah **Pembayaran Tertunda** serta nominal sisa pembayaran.
- Pelunasan menyediakan metode yang sama dengan reservasi: QRIS, OVO, GoPay, ShopeePay, BCA, BNI, BRI, Permata, Mandiri, kartu, dan tunai.
- Setelah memilih metode, pengguna melihat instruksi pembayaran dan nomor rekening/QRIS sebelum konfirmasi.
- Konfirmasi pelunasan menggunakan RPC `settle_appointment_payment`.
- Setelah berhasil, aplikasi menampilkan screen sukses dengan countdown 3 detik lalu kembali ke tab History.
- Notifikasi DP belum lunas tersedia di dalam aplikasi dan sebagai notifikasi HP; tap notifikasi membuka screen pelunasan appointment terkait.
- Reminder appointment dikirim ke HP satu jam sebelum jadwal; appointment yang dibuat kurang dari satu jam akan mendapat reminder segera.
- Reminder lama dibersihkan dan menggunakan ID stabil agar tidak muncul berulang setelah aplikasi dibuka atau jadwal diubah.
- Lima belas menit setelah jadwal dimulai, appointment yang belum selesai mendapat notifikasi expired; tap notifikasi membuka detail dengan pilihan **Ubah Jadwal** atau **Hubungi CS**.
- Tombol **Hubungi CS** membuka WhatsApp dengan kode booking, tanggal, dan jam appointment.
- Pembayaran sukses dikirim sebagai notifikasi HP dan notifikasi in-app.
- Pembayaran masih berstatus demo sampai payment gateway/webhook diterapkan.

---

### 8. 🔓 Lupa PIN Flow

```
PIN Verification → Lupa PIN
  → Input Nomor HP          [layout: header teal + white card]
  → OTP Verification        [layout: header teal + white card]
  → Verifikasi Tanggal Lahir [layout: header teal + white card]
  → Buat PIN Baru           [layout: putih penuh + icon gembok + numpad]
  → Konfirmasi PIN          [layout: putih penuh + icon gembok + numpad]
  → PIN Reset Success Screen (animasi ✓ + countdown 3 detik)
  → Sign In Screen
```

---

### 9. 🛡️ Keamanan & Stabilitas Layout

| Mekanisme | Detail |
|---|---|
| PIN Hashing | SHA-256 (tersimpan di kolom `pin_hash`) |
| PIN Rate Limit | Salah 3x → layar kunci 5 menit |
| OTP Rate Limit | Salah 3x → redirect ke OTP Rate Limit Screen (cooldown 30 detik) |
| Layout Stability | Layout scrollable berbasis `SingleChildScrollView` + `ConstrainedBox` mencegah RenderFlex overflow di layar HP & Web |
| Google Account Picker | `signOut()` sebelum `signIn()` — dialog pilih akun selalu muncul |
| Service-Role Key | Hanya digunakan di Edge Function (server-side), tidak pernah di client |

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
| Profil Completion (HP & Google) | Glassmorphism card dengan gradient background |
| Create PIN (HP & Google) | Putih penuh + icon gembok + numpad |
| Lupa PIN — Input No. Telp | Header teal (logo KEDOTA) + white card bawah |
| Lupa PIN — Verif OTP | Header teal (logo KEDOTA) + white card bawah |
| Lupa PIN — Verif TTL | Header teal (logo KEDOTA) + white card bawah |
| Lupa PIN — Buat PIN Baru | Putih penuh + icon gembok + numpad |
| Edit Profil | White card layout + avatar gradient + dialogs |
| Settings | Header gradient teal + profile card + menu list |

---

## ⚡ Supabase Edge Functions

### Update PIN Function (`update-pin`)

Aplikasi ini menggunakan **Supabase Edge Function** untuk menangani update PIN secara aman, khususnya pada alur lupa PIN di mana user tidak memiliki session aktif.

**Arsitektur Edge Function:**
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

**Endpoint:** `POST /functions/v1/update-pin`

**Deployment Command:**
```bash
supabase login
supabase link --project-ref wwmctqhbqpsbkyxkeaqv
supabase functions deploy update-pin
```

---

## 🗃️ Schema Supabase Database

### Tabel `appointments`

| Kolom | Tipe | Keterangan |
|---|---|---|
| `id` | uuid | Primary key janji temu |
| `booker_id` | uuid | Pemilik janji, terhubung ke `auth.users` |
| `service_type` | text | `Klinik` atau `Home Care` |
| `clinic_name` | text | Klinik/lokasi layanan |
| `appointment_date` | date | Tanggal pertemuan |
| `appointment_time` | time | Jam pertemuan |
| `session_count` | integer | Jumlah sesi dalam paket |
| `appointment_status` | text | `upcoming`, `completed`, `expired`, atau `cancelled` |
| `payment_plan` | text | `full` atau `deposit` |
| `payment_status` | text | `paid`, `pending`, `failed`, atau `expired` |
| `amount_due` | numeric | Sisa pembayaran |
| `booking_code` | text | Kode unik reservasi dengan format `KDT-2026XXXXXX` |
| `assigned_therapist_id` | uuid | Terapis yang ditugaskan, jika tersedia |
| `created_at` / `updated_at` | timestamptz | Waktu pembuatan/perubahan |

Status `completed` seharusnya diubah oleh terapis atau admin melalui RPC, bukan oleh pasien.

### Migration operasional penting

- `20260909000000_add_staff_appointment_status.sql` — role terapis/admin dan RPC update status.
- `20260909000100_prevent_duplicate_appointment_slots.sql` — mencegah slot aktif ganda.
- `20260909000200_expire_overdue_appointments.sql` — auto-expire 15 menit setelah jadwal.
- `20260909000300_reschedule_appointment_rpc.sql` — reschedule aman oleh pemilik janji.
- `20260909000400_settle_appointment_payment_rpc.sql` — RPC pelunasan pembayaran.
- `20260909000000_add_booking_code.sql` — sequence dan kolom kode booking unik.
- `20260909000500_secure_patient_medical_codes.sql` — migrasi ID pasien lama ke kode acak dan unique index.

### Tabel `profiles`

| Kolom | Tipe | Keterangan |
|---|---|---|
| `id` | uuid | Primary key, terhubung ke `auth.users` |
| `phone` | text | Nomor HP format `+62xxx` |
| `full_name` | text | Nama lengkap pengguna |
| `email` | text | Email display pengguna |
| `auth_email` | text | Email identitas Supabase Auth |
| `pin_hash` | text | SHA-256 hash dari PIN 6-digit |
| `birth_date` | date | Tanggal lahir format `YYYY-MM-DD` |
| `gender` | text | `Laki-laki` / `Perempuan` / `Lainnya` |
| `profile_photo_url` | text | URL foto profil dari Supabase Storage |
| `signup_method` | text | `phone` / `google` / `apple` |
| `status` | text | `active` / `deactivated` / `recycled` |
| `is_profile_complete` | bool | Flag kelengkapan profil |
| `medical_code` | text | ID pasien/nomor rekam medis yang tetap untuk pengguna |
| `last_login_at` | timestamptz | Untuk deteksi akun dormant (>60 hari) |
| `created_at` | timestamptz | Waktu registrasi |
| `updated_at` | timestamptz | Waktu perbaruan terakhir |

---

## 📄 Dokumentasi API (OpenAPI 3.0 / Swagger)

Spesifikasi API lengkap tersedia di file: `swagger_supabase_api_spec.txt`.

### Daftar Endpoint Utama:

| Tag | Endpoint | Method | Deskripsi |
|---|---|:---:|---|
| Auth | `/auth/signup` | POST | Registrasi akun via nomor HP |
| Auth | `/auth/signin` | POST | Login via nomor HP + PIN |
| Auth | `/auth/google` | POST | Login / Registrasi Google OAuth |
| Auth | `/auth/apple` | POST | Login Apple OAuth |
| Auth | `/auth/signout` | POST | Logout dari session aktif |
| Auth | `/auth/otp` | POST | Send OTP SMS *(Production Plan)* |
| Auth | `/auth/verify` | POST | Verify OTP token *(Production Plan)* |
| Profiles | `/profiles` | GET / POST | Ambil / Buat data profil |
| Profiles | `/profiles/{id}` | GET / PATCH / DELETE | Detail / Update / Hapus profil |
| Profiles | `/profiles/{id}/pin` | PATCH | Update PIN (session aktif) |
| Profiles | `/profiles/{id}/verify-birth-date` | POST | Verifikasi TTL untuk lupa PIN |
| Profiles | `/profiles/{id}/status` | PATCH | Update status profil |
| Profiles | `/profiles/check-phone` | GET | Cek duplikat nomor HP |
| Profiles | `/profiles/check-email` | GET | Cek duplikat email |
| Profiles | `/profiles/check-status` | GET | Cek status & dormant akun |
| Functions | `/functions/v1/update-pin` | POST | Update PIN via Edge Function (Server-side) |

---

## 🗂️ Struktur Folder Repository

```
lib/
├── l10n/
│   └── app_language.dart                    # Kamus terjemahan lengkap Bahasa Indonesia & English
├── screens/
│   ├── auth/
│   │   ├── account_created_screen.dart      # Screen sukses registrasi
│   │   ├── forgot_pin_screen.dart           # Screen lupa PIN (Input HP, OTP, Verif TTL, Reset PIN)
│   │   ├── google_create_pin_screen.dart    # Buat PIN akun Google
│   │   ├── google_profile_completion_screen.dart # Lengkapi profil Google
│   │   ├── otp_verification_screen.dart     # Input & Verifikasi OTP
│   │   ├── phone_create_pin_screen.dart     # Buat PIN akun HP
│   │   ├── phone_profile_completion_screen.dart # Lengkapi profil HP
│   │   ├── pin_verification_screen.dart     # Input PIN login
│   │   └── sign_in_screen.dart              # Entry screen Sign In & OAuth
│   ├── errors/
│   │   ├── no_internet_screen.dart
│   │   ├── otp_rate_limit_screen.dart       # Cooldown 30s OTP
│   │   ├── pin_rate_limit_screen.dart       # Lock 5m PIN
│   │   └── verification_rate_limit_screen.dart
│   ├── home/
│   │   ├── change_pin_screen.dart           # Ganti PIN dari Settings
│   │   ├── edit_profile_screen.dart         # Edit profil, foto, hide phone, hapus akun
│   │   ├── history_screen.dart              # Riwayat aktivitas & medis
│   │   ├── home_screen.dart                 # Dashboard utama pasien Kedota
│   │   ├── main_screen.dart                 # Bottom Navigation Bar (4 tab)
│   │   ├── notification_preferences_screen.dart # Preferensi notifikasi
│   │   ├── notification_screen.dart         # Halaman daftar notifikasi
│   │   ├── settle_payment_screen.dart        # Instruksi dan pelunasan pembayaran
│   │   ├── progress_screen.dart             # Monitor perkembangan kesehatan
│   │   └── settings_screen.dart             # Settings, toggle bahasa, header profil
│   ├── onboarding/
│   │   └── onboarding_screen.dart
│   └── splash/
│       └── splash_screen.dart               # Auto-routing berdasarkan sesi
├── services/
│   ├── supabase_auth_service.dart           # Service logika autentikasi & profile DB
│   ├── notification_service.dart             # Push notification, reminder, dan deep-link
│   ├── supabase_api_client.dart             # Retrofit API client
│   └── supabase_api_client.g.dart           # Code-generated Retrofit client
├── supabase/
│   ├── config.toml                          # Project config Supabase
│   └── functions/
│       └── update-pin/
│           └── index.ts                     # Edge function update PIN
└── widgets/
    ├── custom_bottom_sheet.dart             # Reusable bottom sheet
    ├── custom_error_screen.dart
    ├── google_logo_icon.dart
    └── language_button.dart
```

---

## 🛠️ Tech Stack

| Komponen | Teknologi |
|---|---|
| Framework | Flutter 3.x (Dart) |
| Backend | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| OAuth | Google Sign-In (Native SDK + Supabase) & Apple Sign-In (OAuth) |
| HTTP Client | Dio + Retrofit (generated) |
| Local Storage | `shared_preferences` |
| Security | SHA-256 PIN Hashing + Phone Masking |
| Server Functions | Supabase Edge Functions (Deno Runtime) |
| API Spec | OpenAPI 3.0 (Swagger) — `swagger_supabase_api_spec.txt` |
| Multi-Language | `AppLanguageScope` (Indonesia & English) |

---

## 🚀 Cara Menjalankan

```bash
# 1. Clone repository
git clone https://github.com/Raihanhidayah12/Kedota-Physiotherapy-App.git
cd kedotaapp

# 2. Install dependencies
flutter pub get

# 3. Jalankan aplikasi
flutter run
```

---

*© 2026 Kedota Physiotherapy App. All Rights Reserved.*
