# 🏥 Kedota Physiotherapy App

> **"Your Comfort, Our Care"** — Aplikasi layanan fisioterapi modern, aman, dan intuitif berbasis Flutter & Supabase.

---

## 📌 Status Proyek (Project Status)

| Fitur / Modul | Status | Keterangan |
| :--- | :---: | :--- |
| 🌐 Multi-Language (EN ⇄ ID) | 🟢 Finished | Full support Bahasa Inggris (default) & Indonesia |
| 🔑 Sign In & PIN Verification | 🟢 Finished | Login HP, SHA-256 PIN Hashing, & Rate Limiting |
| 🌐 Google Sign-In & Profile Completion | 🟢 Finished | Autentikasi Google + Kelengkapan Profil & Gender |
| 📩 Verifikasi OTP Dummy | 🟢 Finished | Terkunci khusus kode `1234`, `5555`, `0000`, `9999` |
| 🛡️ Security & Dormant Account Flow | 🟢 Finished | Proteksi rate limit 3x salah & akun >60 hari |
| 🚀 Persistent Onboarding Flow | 🟢 Finished | SplashScreen `has_seen_onboarding` flag & navigasi cerdas |
| 📝 Sign Up Flow | 🟡 **ON PROGRESS** | **Dalam Tahap Pengaktifan & Pengembangan Aktif** |

---

## ✨ Fitur Utama (Features Implemented)

### 1. 🌐 Internationalization & Multi-Language Support (EN ⇄ ID)
- Dukungan penuh Bahasa Inggris (Default) & Bahasa Indonesia.
- Pengalihan bahasa instan tanpa restart melalui `LanguageButton` & `AppLanguageScope`.
- Seluruh teks formal, rapi, dan konsisten di setiap layar.

### 2. 🔐 Autentikasi Google & Google Profile Completion
- Integrasi **Supabase OAuth** & Google Authentication.
- Pengisian profil lanjutan otomatis:
  - Import Email & Nama dari Google.
  - Input Nomor HP, Tanggal Lahir, Jenis Kelamin (Laki-laki, Perempuan, Lainnya), dan PIN 6-digit.
  - Penyimpanan data aman ke tabel `profiles` Supabase.

### 3. 📱 Double-Layer Phone Lookup Engine
- **Direct PostgREST Filter**: Pencarian otomatis berbagai format nomor HP (`+62...`, `62...`, `0...`).
- **Client-Side Digit Fallback**: Pencocokan cerdas berdasarkan digit inti nomor HP untuk menjamin deteksi profil 100%.

### 4. 🔑 Verifikasi PIN & Keamanan (SHA-256 PIN Hashing)
- Enkripsi PIN 6-digit menggunakan **SHA-256 PIN Hashing**.
- Numpad kustom dengan umpan balik haptik (vibration feedback).

### 5. 📩 Verifikasi OTP Dummy Terkontrol
- Sistem verifikasi OTP dummy untuk pengujian aplikasi secara aman & praktis.
- Terkunci khusus untuk 4 kode OTP spesifik:
  - `1234`
  - `5555`
  - `0000`
  - `9999`

### 6. 🛡️ Keamanan & Anti-Bruteforce (Rate Limiting)
- **PIN Rate Limit**: Mengunci akses selama 5 menit jika gagal 3 kali berturut-turut.
- **OTP Rate Limit**: Proteksi percobaan ulang OTP jika gagal 3 kali.
- **Dormant Account Protection**: Pengalihan verifikasi ke email terdaftar jika akun tidak aktif lebih dari 60 hari.

### 7. 🎨 Estetika & UI/UX Premium
- Desain *Glassmorphism*, gradien warna lembut, dan *Border Radius 32px*.
- Sistem umpan balik interaktif dengan `CustomBottomSheet` (Sukses, Peringatan, & Error).

### 8. 🚀 Persistent Onboarding Experience
- Alur *onboarding* interaktif yang hanya muncul pada peluncuran pertama aplikasi.
- Status `has_seen_onboarding` disimpan secara lokal menggunakan `SharedPreferences`.
- `SplashScreen` cerdas yang secara otomatis merutekan pengguna ke *Onboarding*, *Sign In*, atau langsung ke *Home Dashboard* berdasarkan status sesi autentikasi dan *flag* onboarding.

---

## 🚧 Modul Dalam Pengembangan (On Progress)

- 🟡 **Sign Up Complete Flow**: Integrasi alur pendaftaran mandiri pengguna baru secara penuh.
- ⏳ **Dashboard & Reservation Services**: Pemesanan sesi terapi fisik & manajemen jadwal pasien.
- ⏳ **Medical History**: Catatan perkembangan terapi dan riwayat medis pasien.

---

## 🛠️ Teknologi & Stack (Tech Stack)

- **Framework**: Flutter 3.x (Dart)
- **Backend**: Supabase (PostgreSQL Database, Auth, RLS Policies)
- **State Management**: `ValueNotifier` & Custom `InheritedNotifier`
- **Encryption**: SHA-256 Hashing for PIN Data
- **UI Architecture**: Glassmorphism & Custom Bottom Sheet Design System

---

## 🚀 Cara Menjalankan Aplikasi (Getting Started)

### Prasyarat
- Flutter SDK (`>=3.19.0`)
- Android Studio / VS Code
- Perangkat Android (Fisik / Emulator)

### Langkah-langkah Jalankan
```bash
# 1. Clone repository
git clone https://github.com/username/kedotaapp.git

# 2. Masuk ke folder project
cd kedotaapp

# 3. Unduh dependencies
flutter pub get

# 4. Jalankan aplikasi di HP / Emulator
flutter run
```

---
*© 2026 Kedota Physiotherapy App. All Rights Reserved.*
