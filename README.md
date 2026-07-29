# 🏥 Kedota Physiotherapy App

> **"Your Comfort, Our Care"** — Aplikasi layanan fisioterapi modern, aman, dan intuitif berbasis Flutter & Supabase.

---

## 📌 Status Proyek (Project Status)

| Fitur / Modul | Status | Keterangan |
| :--- | :---: | :--- |
| 🌐 Multi-Language (EN) | 🟢 Finished | Full support Bahasa Inggris (default), ID tersedia |
| 🔑 Sign In & PIN Verification | 🟢 Finished | Login HP, SHA-256 PIN Hashing, & Rate Limiting |
| 🌐 Google Sign-In & Profile Completion | 🟢 Finished | Autentikasi Google + Kelengkapan Profil (2 halaman) |
| 📩 Verifikasi OTP Dummy | 🟢 Finished | Terkunci khusus kode `1234`, `5555`, `0000`, `9999` |
| 🛡️ Security & Dormant Account Flow | 🟢 Finished | Proteksi rate limit 3x salah & akun >60 hari |
| 🚀 Persistent Onboarding Flow | 🟢 Finished | SplashScreen `has_seen_onboarding` flag & navigasi cerdas |
| 🔒 Forgot PIN Flow | 🟢 Finished | Verifikasi tanggal lahir & reset PIN dengan OTP |
| 📱 Indonesian Phone Validation | 🟢 Finished | Validasi nomor HP Indonesia (08xx, 628xx, 8xx) |
| 📝 Sign Up Flow | ⚪ Hidden | Pendaftaran hanya via Google Sign-In |

---

## ✨ Fitur Utama (Features Implemented)

### 1. 🌐 Internationalization & Multi-Language Support
- **Default: Bahasa Inggris**
- Dukungan Bahasa Indonesia tersedia
- Button bahasa disembunyikan (akan ditambahkan di Settings nanti)
- Seluruh teks menggunakan translation system `t(context, 'key')`
- Siap untuk multi-bahasa dengan hanya toggle button

### 2. 🔐 Google Sign-In dengan Flow 2 Halaman
**Flow Authentication:**
```
1. Sign In with Google
2. Pilih akun Google
3. Halaman 1: Isi Profil
   - Nama (auto-fill dari Google)
   - Email (auto-fill dari Google)
   - Nomor HP (input manual)
   - Tanggal Lahir (date picker)
   - Gender (dropdown)
4. Halaman 2: Create PIN
   - Input PIN 6-digit (number pad)
   - Konfirmasi PIN
5. Submit → Home Screen
```

**Keunggulan:**
- ✅ Auto-fill nama & email dari Google
- ✅ PIN terpisah di halaman dedicated dengan number pad
- ✅ Validasi nomor HP Indonesia
- ✅ UX yang clean dan step-by-step

### 3. 📱 Indonesian Phone Number Validation
**Format yang didukung:**
- `08xxxxxxxxx` (11-13 digit)
- `628xxxxxxxxx` (12-14 digit dengan kode negara)
- `8xxxxxxxxx` (10-12 digit tanpa 0 atau kode negara)

**Normalisasi otomatis:**
- Semua format dinormalisasi ke `+628xxxxxxxxx`
- Konsisten di semua screen (Sign In, Sign Up, Forgot PIN, Google Profile)

### 4. 🔑 Verifikasi PIN & Keamanan (SHA-256 PIN Hashing)
- Enkripsi PIN 6-digit menggunakan **SHA-256 PIN Hashing**
- Numpad kustom dengan umpan balik haptik (vibration feedback)
- Visual feedback dengan animated PIN dots

### 5. 📩 Verifikasi OTP Dummy Terkontrol
**Phone OTP (4-digit):**
- `1234`, `5555`, `0000`, `9999`

**Email OTP (6-digit) - untuk future use:**
- `123456`, `000000`

### 6. 🛡️ Keamanan & Anti-Bruteforce (Rate Limiting)
- **PIN Rate Limit**: Mengunci akses selama 5 menit jika gagal 3 kali berturut-turut
- **OTP Rate Limit**: Proteksi percobaan ulang OTP jika gagal 3 kali
- **Dormant Account Protection**: Pengalihan verifikasi ke email jika akun tidak aktif >60 hari

### 7. 🔒 Forgot PIN Flow
**Complete flow untuk reset PIN:**
```
1. Input nomor HP
2. Verifikasi dengan OTP
3. Verifikasi tanggal lahir
4. Create new PIN (number pad)
5. Konfirmasi PIN
6. Success → Redirect ke Sign In
```

### 8. 🎨 Estetika & UI/UX Premium
- Desain *Glassmorphism*, gradien warna lembut
- Sistem umpan balik interaktif dengan `CustomBottomSheet` (Sukses, Peringatan, & Error)
- Consistent color scheme: `#00A79D` (primary), `#17324D` (text)
- Number pad dengan haptic feedback

### 9. 🚀 Persistent Onboarding Experience
- Alur *onboarding* interaktif yang hanya muncul pada peluncuran pertama
- Status `has_seen_onboarding` disimpan secara lokal menggunakan `SharedPreferences`
- `SplashScreen` cerdas yang auto-routing berdasarkan status sesi

---

## 🚧 Modul Dalam Pengembangan (On Progress)

- ⏳ **Dashboard & Reservation Services**: Pemesanan sesi terapi fisik & manajemen jadwal pasien
- ⏳ **Medical History**: Catatan perkembangan terapi dan riwayat medis pasien
- ⏳ **Settings**: Language toggle, profile settings, logout

---

## 🛠️ Teknologi & Stack (Tech Stack)

- **Framework**: Flutter 3.x (Dart)
- **Backend**: Supabase (PostgreSQL Database, Auth, RLS Policies)
- **State Management**: `ValueNotifier` & Custom `InheritedNotifier`
- **Encryption**: SHA-256 Hashing for PIN Data
- **UI Architecture**: Glassmorphism & Custom Bottom Sheet Design System
- **OAuth**: Google Sign-In (Supabase OAuth)
- **Phone Validation**: Indonesian phone number formats

---

## 🚀 Cara Menjalankan Aplikasi (Getting Started)

### Prasyarat
- Flutter SDK (`>=3.19.0`)
- Android Studio / VS Code
- Perangkat Android (Fisik / Emulator)
- Supabase Project (untuk backend)

### Langkah-langkah Jalankan
```bash
# 1. Clone repository
git clone https://github.com/username/kedotaapp.git

# 2. Masuk ke folder project
cd kedotaapp

# 3. Setup .env file
# Copy .env.example ke .env dan isi dengan kredensial Supabase

# 4. Unduh dependencies
flutter pub get

# 5. Jalankan aplikasi di HP / Emulator
flutter run
```

### Testing Credentials
**OTP Dummy:**
- Phone OTP: `1234`, `5555`, `0000`, `9999`
- Email OTP: `123456`, `000000`

**Test Flow:**
1. Sign In dengan nomor HP (08xxx, 628xxx, atau 8xxx)
2. Input OTP dummy
3. Input PIN 6-digit
4. Atau gunakan Google Sign-In untuk registrasi baru

---

## 📝 Authentication Flow

### Sign In (Existing User)
```
Sign In Screen
├── Input: Nomor HP
├── Submit → OTP Verification
├── Input: OTP (1234/5555/0000/9999)
├── Submit → PIN Verification
├── Input: PIN 6-digit
└── Submit → Home Screen
```

### Google Sign-In (New User)
```
Sign In Screen
├── Click: "Continue with Google"
├── Google Account Selection
├── Profile Form Screen
│   ├── Auto-fill: Nama & Email
│   ├── Input: Nomor HP (validated)
│   ├── Select: Tanggal Lahir
│   └── Select: Gender
├── Submit → Create PIN Screen
│   ├── Input: PIN 6-digit (number pad)
│   └── Input: Confirm PIN
└── Submit → Home Screen
```

### Forgot PIN
```
Sign In Screen
├── Click: "Forgot PIN?"
├── Forgot PIN Screen
│   └── Input: Nomor HP
├── Submit → OTP Verification
├── Submit → Birth Date Verification
├── Submit → Create New PIN Screen
│   ├── Input: New PIN 6-digit
│   └── Input: Confirm PIN
└── Submit → Sign In Screen
```

---

*© 2026 Kedota Physiotherapy App. All Rights Reserved.*
