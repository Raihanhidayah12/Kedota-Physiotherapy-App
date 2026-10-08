# Kedota Physiotherapy App

> **"Your Comfort, Our Care"** — Aplikasi layanan fisioterapi berbasis Flutter dan Supabase.

Kedota adalah aplikasi pasien untuk mengelola akun, membuat janji terapi, memantau progres, menerima pengingat, dan mengatur pembayaran. Aplikasi mendukung Android, iOS, dan Web melalui Flutter.

## Status Saat Ini

- Framework: Flutter dengan Dart SDK `^3.12.2`
- Backend: Supabase Auth, PostgreSQL, Storage, REST API, RPC, dan Edge Functions
- Bahasa UI: Bahasa Indonesia (default) dan English melalui kamus terpusat di `lib/l10n/app_language.dart`
- Peta & Geocoding: `flutter_map` (OpenStreetMap tile) + Geoapify API (geocoding akurat) dengan fallback Nominatim
- Pembayaran: alur UI dan RPC pelunasan tersedia; payment gateway masih demo
- Environment: URL dan publishable/anon key Supabase dibaca dari file `.env`
- Pengujian: unit/widget dan integration test tersedia; jalankan pada checkout terkini dengan credential dan device yang sesuai untuk memeriksa hasilnya

---

## 📌 Status Proyek

| Fitur / Modul | Status | Keterangan |
| :--- | :---: | :--- |
| 🌐 Multi-Language (ID / EN) | 🟢 Tersedia | Bahasa Indonesia dan English tersedia melalui kamus terpusat; cakupan perlu dijaga saat menambah UI |
| 🧪 Auth Flow Tests | 🟢 Tersedia | Test auth, onboarding, sign-up, PIN, validasi nomor, dan booking code; hasil tergantung versi kode saat dijalankan |
| 🚀 Onboarding Screen | 🟢 Selesai | Tampil sekali saat pertama buka, 3 slide interaktif (`SharedPreferences`) |
| 🔑 Sign In via Nomor HP | 🟢 Selesai | OTP → PIN → Home Screen |
| 📝 Registrasi via Nomor HP | 🟢 Selesai | OTP → Lengkapi Profil → Buat PIN → Account Created Screen |
| 🌐 Google Sign-In | 🟢 Selesai | OAuth Google → Picker Akun → Lengkapi Profil / Direct PIN → Home |
| 🍎 Apple Sign-In | 🟡 Perlu konfigurasi provider | OAuth melalui Supabase; perlu credential dan konfigurasi Apple Developer untuk production |
| 📩 OTP Verifikasi | 🟡 Mode demo | OTP lokal 4 digit: `1234`, `5555`, `0000`, `9999`; belum memakai penyedia SMS production |
| 📡 OTP Production (Plan) | 🔵 Siap Migrasi | Endpoint `/auth/otp` & `/auth/verify` disiapkan di Swagger |
| 🔓 Lupa PIN | 🟢 Selesai | OTP → Verifikasi Tanggal Lahir → PIN Baru → PIN Reset Success |
| 🔑 Ganti PIN (Settings) | 🟢 Selesai | Verifikasi PIN Lama → Input PIN Baru → Konfirmasi PIN Baru (Rate limit 3x) |
| 👤 Edit Profil | 🟢 Selesai | Ubah Nama, TTL, Gender, Upload/Hapus Foto Profil Supabase Storage |
| 👁️ Privasi Nomor HP | 🟢 Selesai | Default hidden (`+628••••9436`) + Eye Icon toggle di Settings & Edit Profile |
| 🔔 Preferensi Notifikasi | 🟢 Selesai | Push notif, reminder, notifikasi DP/expired, dan deep-link ke detail atau pelunasan |
| 🕒 Urutan & Waktu Notifikasi | 🟢 Selesai | Notifikasi terbaru tampil paling atas dengan waktu relatif |
| ⚙️ Settings & Akun | 🟢 Selesai | Pengaturan profil, preferensi, keamanan, dukungan, dan logout |
| 🛡️ Rate Limiting | 🟢 Selesai | PIN salah 3x → kunci 5 menit, OTP salah 3x → cooldown 30 detik |
| 📴 Deteksi Internet & Error Screen | 🟢 Selesai | Status koneksi device dan akses internet diverifikasi; screen offline dan limit memakai hitung mundur |
| 🕶️ Privasi App Switcher | 🟢 Selesai | Konten aplikasi ditutup saat masuk app switcher pada Android dan iOS |
| 💤 Dormant Account | 🟢 Selesai | Deteksi akun >60 hari tidak aktif → verifikasi via email |
| 🎨 UI & Layout Stability | 🟢 Diimplementasikan | Layout responsif; tetap verifikasi pada ukuran layar dan platform target |
| ⚡ Edge Functions | 🟢 Selesai | Update PIN via server-side function (`update-pin` Deno runtime) |
| 📊 HTTP 5xx Error Logging | 🟢 Teruji | Log uji 5xx berhasil masuk ke tabel `error_logs` pada Supabase |
| 📑 Legal Documents UI | 🟢 Selesai | Syarat & Ketentuan dan Kebijakan Privasi menggunakan accordion |
| 🏠 Home & Main Navigation | 🟢 Selesai | Main Screen dengan 4 tab: Beranda, Progress, Janji Temu, dan Profil |
| 📅 Reservasi Step-by-Step | 🟢 Selesai | 6 tahap dari data pasien hingga instruksi pembayaran, termasuk pilihan lokasi dan jadwal |
| 🗺️ Peta Interaktif (Home Care) | 🟢 Selesai | `flutter_map` + sistem 3 tier Google Maps → Geoapify → OpenStreetMap; Google: `region=ID`, `language=id`, `components=country:ID`; Geoapify: `filter=countrycode:id`; tile dan reverse/forward geocoding dengan fallback otomatis |
| 🔄 Ubah Kontak (HP/Email) | 🟢 Selesai | Ubah nomor HP atau email via OTP, masing-masing maks 1x/hari; tidak bisa mengubah keduanya di hari yang sama; email wajib terverifikasi sebelum bisa diubah |
| 📧 Email Verification | 🟢 Selesai | Verifikasi email ditampilkan sebagai peringatan di profil; pengiriman OTP via Gmail SMTP produksi |
| 🔄 Reschedule | 🟢 Selesai | Screen modern untuk ubah tanggal/jam, validasi slot, dan reminder baru |
| 💳 DP & Pelunasan | 🟢 Selesai (Demo Gateway) | Card appointment tampilkan 2 tombol (Lihat Detail + Lunaskan) saat DP belum lunas |
| 🧾 Identitas Pasien & Booking | 🟢 Selesai | `medical_code` format `KDT-` + 12 karakter; `booking_code` format `EMR-` |
| ⏱️ Auto Expire | 🟢 Selesai | Janji `expired` 15 menit setelah waktu mulai |
| 🔒 Proteksi Slot | 🟢 Selesai | Unique index mencegah dua janji aktif di slot yang sama |
| 📋 Detail Riwayat Done | 🟢 Selesai | Tampilkan catatan klinis, skor progres (VAS/ROM/MMT/ODI), dan rekomendasi terapis dari DB |
| 🔐 REST Payload Encryption (AES-256-CBC + HMAC-SHA256) | 🟢 Selesai | encryptPayload/decryptPayload + enkripsi selektif field sensitif + Dio interceptor |
| 🧪 App Performance Benchmark Tests | 🟢 Selesai | 22 tests, 5 kategori: crypto, hash, phone, address, core utils |
| 🚫 DP Hangus & No-Show | 🟢 Selesai | DP belum lunas hangus saat tidak hadir; pembayaran lunas dapat reschedule maks 24 jam |

---

## ✨ Fitur Utama

### 1. 🚀 Onboarding
- 3 slide interaktif dengan animasi page transition.
- Indikator halaman tetap berada di tempat saat slide berpindah dan memiliki jarak dari tombol bawah.
- Hanya muncul sekali saat pertama kali membuka aplikasi.
- Status disimpan secara lokal menggunakan `SharedPreferences`.

---

### 2. 🔑 Sign In & Registrasi via Nomor HP

**Alur nomor sudah terdaftar:**
```
Sign In → Input Nomor HP
  → OTP Verification (1234 / 5555 / 0000 / 9999 — mode demo lokal)
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
- **Logout dan biometric**: Preferensi biometric dan PIN lokal akun yang logout dihapus dari device. Penguncian ketika aplikasi masuk background tidak menghapus preferensi.
- **Hapus akun**: Tidak tersedia sebagai fitur/menu di versi aplikasi saat ini.

### 4a. 🏠 Beranda & Pengingat Kelengkapan Profil

- Pengingat melengkapi profil muncul untuk akun yang belum memiliki NIK dan alamat lengkap.
- Tombol silang menyimpan status dismiss per akun di device, sehingga pengingat tidak muncul lagi setelah ditutup.
- Pengingat juga tidak ditampilkan lagi jika akun sudah memiliki janji temu.
- Navigasi utama menyediakan tab Beranda, Progress, Janji Temu, dan Profil.
- NIK dan alamat tidak lagi diwajibkan untuk menyelesaikan profil; keduanya bersifat opsional.
- Pengingat profil tidak muncul jika NIK sudah terisi atau jika akun sudah memiliki janji temu.

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

### 6. 📅 Reservasi Jadwal, Layanan & Pembayaran

- Konten tiap tahap masuk dengan animasi fade dan geser ringan; bagian di dalam tahap muncul bertahap.
- Posisi konten tahap tetap dimulai dari atas saat berpindah tahap, termasuk ketika isi tahap pendek.
- Indikator progres tetap di luar area transisi konten sehingga tidak ikut bergeser saat tahap berubah.

Flow reservasi terdiri dari enam tahap:

```
1. Pilih jenis reservasi (diri sendiri atau orang lain)
2. Data pasien (NIK, kode medis, nama, tanggal lahir, nomor telepon, gender, keluhan)
3. Kota, layanan, jadwal, jam, alamat/lokasi
4. Jumlah sesi dan jenis pembayaran (lunas atau DP)
5. Metode pembayaran
6. Instruksi pembayaran atau formulir kartu
```

Tahap pasien memvalidasi NIK 16 digit, nomor HP, serta keluhan wajib. Data identitas yang dikunci ditampilkan dengan gaya abu-abu dan ikon kunci. Tahap jadwal mengunci pilihan yang belum tersedia sampai pilihan sebelumnya diisi.

**Khusus Malang:** tersedia pilihan Klinik **dan** Home Care. Kota lain hanya Home Care.

Untuk Klinik, peta hanya menunjukkan titik tetap Klinik Kedota dan tidak menggunakan geocoding Geoapify. Home Care menggunakan peta yang dapat dipilih, pencarian alamat, dan lokasi terkini.

Tahap pembayaran mendukung QRIS, OVO, GoPay, ShopeePay, transfer BCA/BNI/BRI/Permata/Mandiri, dan kartu kredit/debit. Harga dan nomor rekening dapat disalin; QRIS dapat diunduh. Formulir kartu memvalidasi nomor kartu berdasarkan panjang jaringan dan checksum Luhn, masa berlaku yang belum lewat, serta CVV 3 atau 4 digit sesuai jaringan. Kolom wajib ditandai saat validasi gagal.

Batas pembayaran berlaku 10 menit sejak metode dipilih atau pengguna masuk ke instruksi pembayaran. Setelah kedaluwarsa, instruksi lama dinonaktifkan dan pengguna dapat kembali memilih metode. Integrasi gateway dan konfirmasi transaksi eksternal masih demo; QRIS pada mode demo bukan QR pembayaran gateway.

#### Catatan mode pembayaran

- Rincian biaya dan instruksi transfer/wallet/QRIS adalah bagian dari alur aplikasi; membuka instruksi atau mengunduh QR tidak membuktikan pembayaran berhasil.
- Form kartu kredit/debit hanya memvalidasi input (nomor kartu memakai panjang jaringan dan checksum Luhn, masa berlaku, CVV). Ini bukan pemroses kartu bersertifikasi atau koneksi acquiring bank; jangan masukkan data kartu asli.
- Pelunasan memakai RPC `settle_appointment_payment`, tetapi verifikasi pembayaran eksternal memerlukan gateway dan webhook production.

### 7. 📴 Koneksi Internet & Screen Error

- `NetworkStatusGuard` aktif di seluruh aplikasi. Pemeriksaan memakai status konektivitas device dan probe endpoint health Supabase, bukan data database saja.
- Koneksi diperiksa ketika status jaringan berubah, saat aplikasi kembali aktif, dan berkala setiap 5 detik. Tombol coba lagi menjalankan pemeriksaan ulang.
- Ketika tidak ada akses internet, screen Poor Network Connection menutupi layar aktif sampai koneksi pulih.
- Screen limit OTP, PIN, dan verifikasi tanggal lahir memakai ilustrasi error bersama dan hitung mundur 30 detik. Tombol kembali dan navigasi keluar terkunci sampai waktu habis.
- Error screen bersama dirender melalui `ErrorStateScreen`; teks screen tersedia dalam Bahasa Indonesia dan English.

### 8. 🕶️ Privasi di App Switcher

- Android memasang `FLAG_SECURE` ketika aplikasi masuk background agar snapshot di Recent Apps tidak menampilkan konten aplikasi, lalu melepasnya saat aplikasi aktif kembali.
- iOS memasang privacy cover native pada `sceneWillResignActive` dan menghapusnya saat scene aktif kembali. Cover ini mencegah konten Flutter terlihat di app switcher.
- Perilaku ini hanya menyamarkan tampilan preview; tidak mengubah status login atau preferensi biometric.

### 8a. 🍎 Dukungan iOS

- Target iOS tersedia dengan minimum deployment iOS 13.0.
- `Info.plist` menjelaskan izin kamera, lokasi saat aplikasi digunakan, dan Face ID.
- `SceneDelegate` memasang privacy cover saat aplikasi berpindah ke app switcher.
- `file_saver` menyediakan penyimpanan file untuk iOS; aksi simpan QR menggunakan dialog/pemilih file native.
- Build dan pengujian di iPhone atau simulator belum diverifikasi. Build iOS memerlukan macOS dan Xcode.

---

### 9. 🗺️ Peta Interaktif (Home Care)

Fitur peta digunakan khusus pada alur reservasi Home Care dan menerapkan sistem **3 tier cascading fallback** untuk keandalan tinggi.

**Hierarki layanan tile peta:**
1. **Google Maps** (utama) — tile Google Maps dengan kualitas premium
2. **Geoapify** (sekunder) — tile `osm-bright` style, failover otomatis
3. **OpenStreetMap** (tersier) — tile standar OSM, selalu tersedia gratis

**Hierarki geocoding (forward & reverse):**
```
Google Maps Geocoding API (akurat, berbayar per-request)
    ↓ gagal / quota habis
Geoapify API (3000 req/hari gratis)
    ↓ gagal / quota habis
Nominatim OpenStreetMap (gratis unlimited)
```

**Fitur:**
- **Reverse geocoding** (koordinat → alamat): tap peta atau gunakan lokasi terkini → field Alamat terisi otomatis dengan format `Jalan, Kelurahan, Kecamatan, Kota, Provinsi, Kode Pos`.
- **Forward geocoding** (ketik alamat → pindah peta): debounce 900ms → peta dan marker sinkron ke lokasi.
- **Popup peta** (fullscreen): floating label alamat di atas peta, field detail di bawah, tombol ✕ untuk confirm & tutup.
- **Lokasi Terkini**: `LocationAccuracy.bestForNavigation` untuk akurasi GPS tertinggi.
- **Atribusi real-time**: label atribusi di peta berubah sesuai layanan yang aktif.
- **Debug logging**: setiap pergantian layanan dicatat untuk memudahkan troubleshooting.

**Environment:**
```dotenv
GOOGLE_MAPS_API_KEY=<google-maps-api-key>
GEOAPIFY_API_KEY=<geoapify-api-key>
```

Gunakan `GEOAPIFY_API_KEY` (bukan `GEOAPPIFY_API_KEY`) di file `.env`.

**Reliabilitas:** sistem multi-tier mencapai uptime ~99.9% — layanan premium digunakan saat tersedia, fallback gratis menjaga fungsionalitas saat terjadi gangguan.

### 9a. 📧 Email Verification & Medical Code

**Email Verification:**
- Verifikasi email ditampilkan sebagai **peringatan di screen profil** alih-alih di alur registrasi inline.
- Pengiriman OTP nyata melalui integrasi **Gmail SMTP** yang dikonfigurasi di Supabase Auth.
- Pengguna dapat menyelesaikan registrasi dan menggunakan aplikasi sebelum memverifikasi email.

**Medical Code (Kode Pasien):**
- Kode medis pasien (`medical_code`) digenerate **otomatis** saat pembuatan profil.
- Format: `KDT-` diikuti 12 karakter heksadesimal acak (contoh: `KDT-a3f8c1e20b94`).
- Unik per pasien; digunakan sebagai identitas di formulir reservasi.

**Change Contact Flow:**
- Pengguna dapat mengganti nomor HP atau email melalui alur OTP verification yang komprehensif.
- Setiap perubahan kontak memerlukan verifikasi OTP ke nomor/email baru sebelum tersimpan.
- **Pembatasan frekuensi:** Nomor HP dan email masing-masing hanya dapat diubah **1x per hari**.
- Nomor HP dan email **tidak dapat diubah pada hari yang sama** (mutual exclusion per hari).
- Pengguna hanya dapat mengubah email jika **email sudah diverifikasi** (`email_verified = true`). Jika belum, ditampilkan info bottom sheet dan navigasi ke ChangeContactScreen diblokir.
- OTP perubahan nomor HP menggunakan **4 digit** (bukan 6).
- Saat menyimpan nomor baru atau email baru, sistem memeriksa duplikat dengan multi-variant phone matching (+62, 62, 08, 8) untuk nomor HP.
- Kolom `phone_changed_at` dan `email_changed_at` (timestamptz) dicatat di tabel `profiles` saat perubahan berhasil.

---

### 10. 💳 Pembayaran DP & Pelunasan

- Card appointment menampilkan **2 tombol** saat DP belum lunas: "Lihat Detail" (outline) + "Lunaskan Pembayaran" (solid).
- Saat DP lunas atau hangus: hanya tombol "Lihat Detail".
- Metode pembayaran: QRIS, OVO, GoPay, ShopeePay, BCA, BNI, BRI, Permata, Mandiri, kartu, tunai.
- Pelunasan menggunakan RPC `settle_appointment_payment`.
- Setelah berhasil: screen sukses countdown 3 detik → tab History.
- Pembayaran masih demo sampai payment gateway/webhook diterapkan.

---

### 11. 📋 Detail Riwayat — Status Done

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

### 12. 🔔 Notifikasi In-App

- Terbaru tampil paling atas berdasarkan `created_at`.
- Waktu relatif: `Baru saja`, `2 menit yang lalu`, `3 jam yang lalu`, `Kemarin`.
- Label tersedia dalam ID & EN.

### 13. 📑 Syarat, Ketentuan & Kebijakan Privasi

- UI accordion — setiap section buka/tutup.
- Tanggal `Terakhir diperbarui` mengikuti tanggal perangkat.

### 14. 📊 Logging Error HTTP 5xx

- Global error handler aktif sejak app dibuka.
- Mendeteksi response `500-599` dari semua jalur: Dio, Supabase Auth, DB, Storage, RPC.
- Metadata error dikirim ke Edge Function `client-error-log` secara background.
- Migration tabel `error_logs` dan Edge Function `client-error-log` sudah diterapkan ke project Supabase.
- Setelah aktif, cek data di **Supabase Dashboard → Table Editor → `error_logs`**. Log runtime Edge Function bisa dilihat di **Logs → Edge Functions → `client-error-log`**.
- Pengujian dashboard berhasil menyimpan log uji (`GET /test/error-log`, status `500`) ke tabel. Hapus baris tersebut jika tabel ingin berisi log kejadian nyata saja.
- Edge Function mengembalikan error jika penyimpanan database gagal atau konfigurasi server belum ada.
- Dokumentasi: [`docs/5xx-error-logging.md`](docs/5xx-error-logging.md)

### 15. 🔓 Lupa PIN Flow

```
PIN Verification → Lupa PIN
  → Input Nomor HP → OTP Verification → Verifikasi Tanggal Lahir
  → Buat PIN Baru → Konfirmasi PIN
  → PIN Reset Success Screen (animasi ✓ + countdown 3 detik)
  → Sign In Screen
```

---

### 16. 🛡️ Keamanan & Stabilitas

| Mekanisme | Detail |
|---|---|
| PIN Hashing | SHA-256 (kolom `pin_hash`) |
| Batas Verifikasi | OTP/PIN/tanggal lahir memakai screen limit dengan hitung mundur 30 detik |
| PIN Rate Limit | Salah 3x → kunci 5 menit |
| OTP Rate Limit | Salah 3x → cooldown 30 detik |
| Layout Stability | `SingleChildScrollView` + `ConstrainedBox` mencegah overflow |
| Google Account Picker | `signOut()` sebelum `signIn()` — dialog selalu muncul |
| Biometric saat logout | Biometric aplikasi dan PIN lokal akun dinonaktifkan saat logout eksplisit; penguncian saat aplikasi berpindah/background tidak menghapus preferensi |
| Service-Role Key | Hanya di Edge Function, tidak pernah di client |
| Batas Perubahan Kontak | Nomor HP dan email masing-masing hanya bisa diubah 1x/hari; tidak bisa mengubah keduanya di hari yang sama; email wajib terverifikasi |
| Enkripsi Payload REST | AES-256-CBC; envelope `{data, iv, sig}`; diterapkan otomatis via Dio interceptor |
| Integritas Payload (HMAC) | HMAC-SHA256; perbandingan constant-time; tampered payload direjek |
| Constant-time Comparison | `_constantTimeEquals` mencegah timing attack pada verifikasi HMAC |

---

### 17. 🔐 REST Payload Encryption

Aplikasi menggunakan enkripsi AES-256-CBC + HMAC-SHA256 untuk melindungi payload REST pada endpoint sensitif. Implementasi terdiri dari dua lapisan:

**Full Envelope (`encryptPayload` / `decryptPayload`)**

Seluruh request body dienkripsi dan dikemas dalam envelope:
```json
{ "data": "<base64-ciphertext>", "iv": "<base64-iv>", "sig": "<hmac-hex>" }
```
- IV acak baru di setiap request (AES-256-CBC).
- HMAC-SHA256 dihitung atas `data + iv` menggunakan `REST_HMAC_KEY`.
- Signature diverifikasi sebelum dekripsi; jika tidak cocok, `SecurityException` dilempar.
- Interceptor memanggil `handler.reject()` — payload yang telah diubah tidak pernah diteruskan ke aplikasi.

**Enkripsi Selektif (`encryptSensitiveFields` / `decryptSensitiveFields`)**

Hanya field sensitif tertentu yang dienkripsi per-field:
- Field: `pin_hash`, `pin`, `patient_nik`, `patient_phone`, `phone`, `new_pin_hash`, `new_pin`
- Field lain tetap plaintext sehingga routing dan non-sensitive logic tidak berubah.

**Dio Interceptor (`RestCryptoInterceptor`)**

- Mendaftar di `supabase_auth_service.dart` `apiClient` getter.
- Endpoint yang dienkripsi otomatis:
  - `/functions/v1/update-pin`
  - `/functions/v1/client-error-log`
- Menambahkan header `X-Encrypted: 1` dan `X-Encryption: AES-256-CBC` pada request terenkripsi.
- Mendekripsi response secara otomatis.

**Keamanan**

- Perbandingan HMAC menggunakan constant-time (`_constantTimeEquals`) — mencegah timing attack.
- Validasi panjang kunci: `REST_ENCRYPT_KEY` wajib 64 hex chars (32 byte), `REST_HMAC_KEY` ≥ 64 hex chars.
- Kunci test bersifat sintetis dan tidak identik dengan kunci produksi.

**Unit Test:** `test/utils/rest_crypto_test.dart` — 10 test, semua passing: round-trip, random IV, 3x tamper detection (data/iv/sig), enkripsi selektif, tamper selektif, validasi kunci x2.

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
| Reservasi | 6 tahap dengan transisi dan animasi isi, form pasien, jadwal/lokasi, sesi, pilihan pembayaran, dan instruksi pembayaran |
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

`client-error-log` menerima metadata error HTTP 5xx dan menyimpannya ke `public.error_logs` memakai service-role key di sisi server. Pengujian dashboard berhasil memasukkan satu baris uji (`/test/error-log`, status 500); hapus baris tersebut jika tabel hanya akan berisi kejadian operasional. Cek data melalui **Dashboard → Table Editor → `error_logs`**, dan runtime logs melalui **Edge Functions → `client-error-log` → Logs**.

---

## 🗃️ Schema Supabase Database

Kolom berikut merangkum kolom yang dipakai aplikasi, bukan dump lengkap dari database live. Project Supabase saat ini memiliki tabel `error_logs` yang sudah diuji. Folder `supabase/migrations` belum berisi migration lengkap untuk schema `profiles`, `appointments`, Storage, RPC, dan policies. Karena itu database live belum dapat direkonstruksi hanya dengan `supabase db push`; simpan perubahan yang dibuat di Dashboard sebagai migration SQL sebelum menyiapkan project baru.

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
| `is_profile_complete` | boolean | Flag kelengkapan profil (bukan penentu utama routing) |
| `medical_code` | text | Format `KDT-` + 12 karakter acak unik |
| `email_verified` | boolean | Default `false`; `true` setelah pengguna memverifikasi email |
| `last_login_at` | timestamptz | Deteksi akun dormant (>60 hari) |
| `created_at` / `updated_at` | timestamptz | Timestamp |
| `phone_changed_at` | timestamptz | *(nullable)* Timestamp terakhir nomor HP diubah; digunakan untuk rate-limit 1x/hari |
| `email_changed_at` | timestamptz | *(nullable)* Timestamp terakhir email diubah; digunakan untuk rate-limit 1x/hari |

---

## 🛠️ Tech Stack

| Komponen | Teknologi |
|---|---|
| Framework | Flutter 3.x (Dart SDK `^3.12.2`) |
| Backend | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| OAuth | Google Sign-In & Apple Sign-In (OAuth) |
| HTTP Client | Dio + Retrofit (generated) |
| Peta | `flutter_map` v8 + Google Maps tiles & geocoding (utama) + Geoapify tile & geocoding (sekunder) + OpenStreetMap/Nominatim (tersier) |
| Lokasi | `geolocator` + `geocoding` (fallback) |
| Koneksi | `connectivity_plus` + probe HTTP Supabase untuk deteksi internet |
| Local Storage | `shared_preferences` |
| Simpan QR | `file_saver` 0.6.0 + pemilih file native pada platform yang mendukung |
| Security | SHA-256 PIN Hashing + Phone Masking |
| Enkripsi REST | `encrypt` ^5.0.3 + `crypto` (AES-256-CBC + HMAC-SHA256) |
| Server Functions | Supabase Edge Functions (Deno Runtime) |
| Multi-Language | `AppLanguageScope` (Indonesia default + English) |
| Observability | Dio interceptor + Flutter error handler + `client-error-log` Edge Function |
| API Spec | OpenAPI 3.0 — `swagger_supabase_api_spec.txt` |

`file_saver` 0.6.0 memakai `meta ^1.19.0`. Flutter 3.44.6 mematok `meta 1.18.0` lewat `flutter_test`, sehingga `pubspec.yaml` memakai `dependency_overrides` untuk menyelesaikan dependensi. Setelah Flutter SDK diperbarui ke versi dengan pin `meta` yang sesuai, override ini dapat dievaluasi kembali.

---

## Konfigurasi dan Menjalankan Proyek

### Persyaratan

- Flutter SDK dengan Dart yang memenuhi batas `^3.12.2` di `pubspec.yaml`.
- Supabase project, URL, dan publishable/anon key.
- Untuk iOS: macOS, Xcode, CocoaPods, dan signing team Apple.
- Untuk OAuth production: provider dan callback/redirect URL dikonfigurasi di Supabase serta Google/Apple Developer Console.

### Environment

Salin `.env.example` menjadi `.env`, lalu isi:

```dotenv
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<publishable-or-anon-key>
GOOGLE_MAPS_API_KEY=<google-maps-api-key>
GEOAPIFY_API_KEY=<geoapify-api-key>
REST_ENCRYPT_KEY=<64-hex-char AES-256 key>
REST_HMAC_KEY=<64+-hex-char HMAC-SHA256 key>
```

`.env` disertakan sebagai asset Flutter sehingga nilainya dapat dibaca dari aplikasi client. Gunakan hanya publishable/anon key di sini. GOOGLE_MAPS_API_KEY dan GEOAPIFY_API_KEY adalah kunci API opsional yang digunakan untuk sistem fallback peta pada alur reservasi homecare. Jika Google Maps tidak tersedia, aplikasi secara otomatis beralih ke Geoapify kemudian OpenStreetMap. Jangan masukkan service-role key atau secret provider ke client; Edge Functions menggunakan konfigurasi server Supabase. REST_ENCRYPT_KEY (64 hex chars, 32 byte) dan REST_HMAC_KEY (minimal 64 hex chars) digunakan untuk enkripsi AES-256-CBC dan verifikasi HMAC-SHA256 payload pada endpoint sensitif. Jangan masukkan nilai kunci produksi ke repository.

### Menjalankan

```bash
flutter pub get
flutter run
```

Gunakan `flutter devices` untuk melihat device dan `flutter run -d <device-id>` untuk memilihnya. iOS build memerlukan macOS/Xcode. Web dapat dicoba dengan `flutter run -d chrome`, tetapi plugin dan fitur native harus diverifikasi per browser.

### OAuth callback

- Aktifkan provider yang dipakai di Supabase Auth dan daftarkan URL redirect/callback setiap platform.
- Android callback scheme tercantum di `android/app/src/main/AndroidManifest.xml`: `io.supabase.flutter://login-callback`.
- Cocokkan package/bundle identifier, client ID, URL scheme, dan callback URL dengan konfigurasi provider.
- Apple Sign-In memerlukan capability dan credential Apple Developer; credential tersebut tidak disediakan repository.

### Build dan kesiapan rilis

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

Build iOS hanya dapat dibuat di macOS/Xcode. Android release saat ini menggunakan debug signing; atur signing key sendiri sebelum distribusi. Verifikasi OAuth, notifikasi, izin kamera/lokasi, penyimpanan QR, dan privacy cover di device tiap platform sebelum rilis.

---

## Peta Kode

| Lokasi | Tanggung jawab |
|---|---|
| `lib/main.dart` | Bootstrap, dotenv, Supabase, global error handler, tema, dan lock wrapper |
| `lib/screens/onboarding/` | Slide onboarding |
| `lib/screens/auth/` | Sign-in, OTP demo, PIN, pendaftaran, dan pemulihan PIN |
| `lib/screens/errors/` | Offline dan rate limit OTP/PIN/verifikasi |
| `lib/screens/home/` | Home, reservasi, janji, riwayat, profil, settings, pembayaran, dan notifikasi |
| `lib/services/supabase_auth_service.dart` | Auth, operasi Supabase, REST client, booking/profile logic |
| `lib/services/network_status_service.dart` | Status jaringan device dan probe koneksi Supabase |
| `lib/services/client_error_log_service.dart` | Deteksi dan pengiriman metadata HTTP 5xx |
| `lib/services/notification_service.dart` | Notifikasi lokal dan jadwal/payload appointment |
| `lib/services/app_lock_service.dart` | Preferensi app lock dan autentikasi biometrik lokal |
| `lib/services/screen_security_service.dart` | Perlindungan preview aplikasi Android/iOS |
| `lib/l10n/app_language.dart` | Kamus Bahasa Indonesia dan English |
| `lib/widgets/` | Komponen reusable, network guard, error state, dan bottom sheet |
| `lib/utils/` | Snackbar, validasi nomor telepon, dan kode booking |
| `lib/utils/rest_crypto.dart` | AES-256-CBC enkripsi/dekripsi payload REST + validasi kunci + SecurityException |
| `lib/utils/rest_crypto_interceptor.dart` | Dio interceptor otomatis enkripsi request & dekripsi response endpoint sensitif |
| `supabase/functions/` | Edge Functions `update-pin` dan `client-error-log` |
| `test/`, `integration_test/` | Unit/widget test dan integration test |
| `test/performance/` | Benchmark test 5 kategori: crypto, hash, phone, address, core utils |

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
    ├── phone_validator.dart
    ├── rest_crypto.dart
    └── rest_crypto_interceptor.dart
test/
├── performance/
│   ├── crypto_benchmark_test.dart          # AES-256-CBC + HMAC-SHA256 encrypt/decrypt benchmark
│   ├── pin_hash_benchmark_test.dart        # SHA-256 hashPin benchmark
│   ├── phone_validator_benchmark_test.dart # normalizePhoneNumber + isValidIndonesianPhone benchmark
│   ├── address_format_benchmark_test.dart  # Regex address formatting benchmark
│   └── app_performance_test.dart           # BookingCode, MedicalCode, DateTime, JSON benchmark
```

---

Modul lintas fitur: `network_status_service.dart` memeriksa koneksi, `network_status_guard.dart` menampilkan screen offline, `error_state_screen.dart` menyediakan layout error umum, dan `rate_limit_screen.dart` menangani hitung mundur limit.

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
flutter test
```

Jalankan test pada checkout terkini; README ini tidak menganggap hasil test sebelumnya sebagai hasil untuk perubahan terbaru.

Integration test di `integration_test/app_test.dart` membutuhkan device Android/iOS, `.env`, dan koneksi Supabase.

### 🏎️ App Performance Benchmark Tests

Benchmark test tersedia di folder `test/performance/` — 22 test, semua passing. Setiap file mengukur throughput dan latensi rata-rata pada komponen inti:

| File | Apa yang diuji | Iterasi | Threshold |
|---|---|---|---|
| `crypto_benchmark_test.dart` | `encryptPayload`, `decryptPayload`, `encryptSensitiveFields`, `decryptSensitiveFields` (AES-256-CBC + HMAC-SHA256) | 1 000x | < 10 ms avg |
| `pin_hash_benchmark_test.dart` | SHA-256 `hashPin` + validasi correctness terhadap known digest | 10 000x | < 1 ms avg |
| `phone_validator_benchmark_test.dart` | `normalizePhoneNumber` + `isValidIndonesianPhone` (format +62, 08, 8, 62) | 10 000x | < 1 ms avg |
| `address_format_benchmark_test.dart` | Regex address cleaning `_formatAddressForDisplay` (East Java→Jawa Timur, strip ", Indonesia", ", JI") | 1 000x | < 0,5 ms avg |
| `app_performance_test.dart` | BookingCode gen, MedicalCode gen, DateTime formatting, JSON encode/decode (realistic appointment payload) | 10 000x / 1 000x | < 1 ms avg |

**Cara menjalankan:**

```bash
flutter test test/performance/
```

**Format output:**

```
[PERF] encryptPayload 1000x: total=450ms avg=0.4500ms
[PERF] hashPin 10000x: total=120ms avg=0.0120ms
[PERF] normalizePhone 10000x: total=85ms avg=0.0085ms
[PERF] formatAddress 1000x: total=12ms avg=0.0120ms
[PERF] bookingCode 10000x: total=95ms avg=0.0095ms
```

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
supabase functions deploy client-error-log
supabase functions deploy update-pin
```

Jangan menjalankan `supabase db push` untuk membuat environment baru sebelum migration schema lengkap ditambahkan dan direview; database live saat ini tidak seluruhnya direpresentasikan di `supabase/migrations`.

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

Untuk mengaktifkan pembatasan frekuensi perubahan kontak (1x/hari per field, mutual exclusion), tambahkan kolom berikut ke tabel `profiles`:

```sql
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS phone_changed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS email_changed_at TIMESTAMPTZ;
```

---

*© 2026 Kedota Physiotherapy App. All Rights Reserved.*
