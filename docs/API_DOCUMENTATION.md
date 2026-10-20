# Kedota Physiotherapy App - Panduan & Dokumentasi API Lengkap

Dokumentasi ini menyajikan referensi menyeluruh arsitektur API, spesifikasi Swagger (OpenAPI 3.0.3), pemetaan setiap screen/layanan di aplikasi Flutter Kedota, serta detail lengkap skema database PostgREST (semua tabel dan setiap kolom yang digunakan).

---

## 1. Berkas Spesifikasi Swagger yang Tersedia

Seluruh berkas spesifikasi API telah digenerate dan tersimpan di folder `docs/`:

1. **`docs/swagger-ui.html`**: Antarmuka interaktif **Swagger UI** mandiri (standalone). Anda cukup klik ganda atau membukanya di browser apa pun (Chrome, Edge, Firefox) untuk langsung melihat visualisasi dokumentasi, skema model, dan menguji request endpoint.
2. **`docs/swagger.yaml`**: Spesifikasi OpenAPI 3.0.3 dalam format YAML standar (bisa diimpor ke Postman, Insomnia, SwaggerHub, dsb).
3. **`docs/swagger.json`**: Spesifikasi OpenAPI 3.0.3 dalam format JSON standar.

---

## 2. Pemetaan Screen / Halaman Aplikasi ke Endpoint API

Berikut adalah tabel pemetaan lengkap antara setiap screen di dalam aplikasi Flutter (`lib/screens/`) dengan endpoint HTTP, metode (GET, POST, PATCH, PUT, DELETE), serta tabel database yang terlibat:

| Screen / Halaman | File Sumber Dart | Metode HTTP | Endpoint API | Tabel / Sumber Daya | Keterangan & Fungsi |
| :--- | :--- | :---: | :--- | :--- | :--- |
| **Splash Screen** | `lib/screens/splash/splash_screen.dart` | `GET` | `/auth/v1/user` | Auth Session | Cek token sesi user aktif di perangkat |
| | | `POST` | `/auth/v1/token?grant_type=refresh_token` | Auth Session | Refresh access token jika token lama expired |
| | | `GET` | `/rest/v1/profiles?id=eq.{id}` | `public.profiles` | Cek status `is_profile_complete` dan `signup_method` |
| **Onboarding Screen** | `lib/screens/onboarding/onboarding_screen.dart` | - | - | Lokal / Cache | Panduan selamat datang & edukasi layanan fisioterapi |
| **Sign In Screen** | `lib/screens/auth/sign_in_screen.dart` | `GET` | `/rest/v1/profiles?phone=eq.{phone}` | `public.profiles` | Cek ketersediaan nomor HP (`checkAccountStatus`) |
| | | `POST` | `/auth/v1/token?grant_type=id_token` | Auth OAuth | Sign-in via Google (ID Token) atau Apple ID Token |
| | | `POST` | `/auth/v1/otp` | SMS / WhatsApp | Kirim OTP jika nomor belum terdaftar atau reset |
| **OTP Verification Screen** | `lib/screens/auth/otp_verification_screen.dart` | `POST` | `/auth/v1/otp` | Auth OTP | Kirim ulang OTP (Resend OTP) jika waktu tunggu habis |
| | | `POST` | `/auth/v1/verify` | Auth OTP | Verifikasi 6-digit OTP SMS (`type: sms`) atau email |
| **Create PIN (Phone & Google)** | `lib/screens/auth/*_create_pin_screen.dart` | - | - | Client Cryptography | Input & hashing 6-digit PIN dengan algoritma SHA-256 |
| **Complete Profile & Sign Up** | `lib/screens/auth/*_profile_completion_screen.dart` | `POST` | `/auth/v1/signup` | Supabase Auth | Daftarkan akun baru dengan email/phone & PIN password |
| | | `POST` | `/storage/v1/object/profile-photos/{uid}/{file}` | Storage `profile-photos` | Upload foto profil baru pengguna (JPEG/PNG) |
| | | `POST` | `/rest/v1/profiles` | `public.profiles` | Insert record biodata lengkap pasien & kode rekam medis |
| **PIN Verification Screen** | `lib/screens/auth/pin_verification_screen.dart` | `GET` | `/rest/v1/profiles?phone=eq.{phone}` | `public.profiles` | Mengambil data `pin_hash` dan `auth_email` |
| | | `POST` | `/auth/v1/token?grant_type=password` | Supabase Auth | Sign in dengan email auth dan password PIN 6-digit |
| | | `PATCH` | `/rest/v1/profiles?id=eq.{id}` | `public.profiles` | Update timestamp login terakhir (`last_login_at`) |
| **Forgot PIN Screen** | `lib/screens/auth/forgot_pin_screen.dart` | `GET` | `/rest/v1/profiles?phone=eq.{phone}` | `public.profiles` | Validasi nomor HP dan tanggal lahir pasien |
| | | `POST` | `/auth/v1/otp` | SMS / WhatsApp | Kirim OTP otorisasi reset PIN |
| | | `POST` | `/functions/v1/update-pin` | Edge Function | Reset PIN baru secara aman (terenkripsi AES-GCM) |
| **Email Verification Dialog** | `lib/screens/auth/email_verification_dialog.dart` | `POST` | `/auth/v1/otp` | Auth Email | Kirim kode OTP verifikasi ke email |
| | | `POST` | `/auth/v1/verify` | Auth Email | Validasi OTP email pengguna |
| | | `PATCH` | `/rest/v1/profiles?id=eq.{id}` | `public.profiles` | Update status `email_verified = true` & `email_changed_at` |
| **Home & Dashboard Screen** | `lib/screens/home/home_screen.dart` | `POST` | `/rest/v1/rpc/expire_overdue_appointments` | PostgreSQL RPC | Otomatis ubah status janji temu terlambat jadi `expired` |
| | | `GET` | `/rest/v1/profiles?id=eq.{id}` | `public.profiles` | Ambil nama pasien, foto avatar, dan kode medis |
| | | `GET` | `/rest/v1/appointments?booker_id=eq.{id}&...` | `public.appointments` | Ambil 1 janji temu mendatang terdekat (`upcoming`) |
| **Reservation Flow Screen** | `lib/screens/home/reservation_flow_screen.dart` | `GET` | `/rest/v1/profiles?id=eq.{id}` | `public.profiles` | Pre-fill biodata pasien (NIK, Nama, HP, Alamat, dll.) |
| | | `GET` | `/rest/v1/appointments?appointment_date=eq...` | `public.appointments` | Validasi slot tanggal/waktu agar tidak tabrakan/ganda |
| | | `POST` | `/rest/v1/appointments` | `public.appointments` | Simpan data reservasi baru (Klinik / Home Care) |
| **History Screen (Riwayat)** | `lib/screens/home/history_screen.dart` | `GET` | `/rest/v1/appointments?booker_id=eq.{id}` | `public.appointments` | Ambil seluruh daftar janji temu pasien (order tanggal desc) |
| | | `GET` | `/rest/v1/appointments?appointment_status=eq...` | `public.appointments` | Filter tab: Mendatang, Selesai, Batas Waktu, Dibatalkan |
| **Appointment Detail Screen** | `lib/screens/home/appointment_detail_screen.dart` | `GET` | `/rest/v1/appointments?id=eq.{id}` | `public.appointments` | Ambil detail lengkap, catatan medis, skor VAS/ROM/MMT/ODI |
| | | `PATCH` | `/rest/v1/appointments?id=eq.{id}` | `public.appointments` | Pembatalan janji temu (`appointment_status = 'cancelled'`) |
| | | `DELETE` | `/rest/v1/appointments?id=eq.{id}` | `public.appointments` | Menghapus record appointment dari sistem |
| **Reschedule Appointment** | `lib/screens/home/reschedule_appointment_screen.dart` | `GET` | `/rest/v1/appointments?appointment_date=eq...` | `public.appointments` | Validasi ketersediaan slot tanggal & jam baru |
| | | `POST` | `/rest/v1/rpc/reschedule_appointment` | PostgreSQL RPC | Pindahkan jadwal janji temu dengan aturan batas waktu H-24 |
| **Settle Payment Screen** | `lib/screens/home/settle_payment_screen.dart` | `GET` | `/rest/v1/appointments?id=eq.{id}&select=amount_due...` | `public.appointments` | Mengambil nilai sisa tagihan deposit |
| | | `POST` | `/rest/v1/rpc/settle_appointment_payment` | PostgreSQL RPC | Pelunasan tagihan sisa (`payment_status = 'paid'`, `amount_due = 0`) |
| **Notification Screen** | `lib/screens/home/notification_screen.dart` | `GET` | `/rest/v1/appointments?booker_id=eq.{id}` | `public.appointments` | Log pemberitahuan jadwal baru, konfirmasi pembayaran, dsb. |
| **Settings & Profile Screen** | `lib/screens/home/settings_screen.dart` | `GET` | `/rest/v1/profiles?id=eq.{id}` | `public.profiles` | Mengambil data akun dan preferensi |
| | | `POST` | `/auth/v1/logout` | Supabase Auth | Sign out dari sesi aktif |
| | | `DELETE` | `/rest/v1/profiles?id=eq.{id}` | `public.profiles` | Hapus / nonaktifkan akun pengguna |
| **Edit Profile Screen** | `lib/screens/home/edit_profile_screen.dart` | `GET` | `/rest/v1/profiles?id=eq.{id}` | `public.profiles` | Pre-fill form edit profil |
| | | `POST` | `/storage/v1/object/profile-photos/{uid}/{file}` | Storage Bucket | Upload foto avatar baru |
| | | `DELETE` | `/storage/v1/object/profile-photos/{uid}/{file}` | Storage Bucket | Hapus foto profil lama |
| | | `PATCH` | `/rest/v1/profiles?id=eq.{id}` | `public.profiles` | Update nama, NIK, tanggal lahir, gender, alamat, foto |
| **Change Contact Screen** | `lib/screens/home/change_contact_screen.dart` | `POST` | `/auth/v1/otp` | SMS / Email OTP | Kirim OTP verifikasi ke nomor HP / email baru |
| | | `POST` | `/auth/v1/verify` | Auth OTP | Validasi kode OTP sebelum data kontak diubah |
| | | `PATCH` | `/rest/v1/profiles?id=eq.{id}` | `public.profiles` | Update kolom `phone`, `email`, `phone_changed_at`, dll. |
| **Change PIN Screen** | `lib/screens/home/change_pin_screen.dart` | `POST` | `/functions/v1/update-pin` | Edge Function | Perbarui PIN dengan payload terenkripsi AES-GCM + HMAC |
| **Client Error Logging** | `lib/services/client_error_log_service.dart` | `POST` | `/functions/v1/client-error-log` | Edge Function & `error_logs` | Catat kegagalan server HTTP 5xx dari aplikasi Flutter |
| | | `GET` | `/rest/v1/error_logs` | `public.error_logs` | Audit riwayat error internal (khusus admin/service_role) |

---

## 3. Kamus Data Lengkap (Database Dictionary)

Setiap kolom dan tipe data yang digunakan dalam database PostgreSQL / Supabase untuk aplikasi Kedota diuraikan secara rinci di bawah ini:

### A. Tabel `public.profiles` (21 Kolom)
Tabel utama yang menyimpan data akun, profil, dan rekam medis pasien.

| Nama Kolom | Tipe Data PostgreSQL | Constraint & Default | Keterangan & Deskripsi |
| :--- | :--- | :--- | :--- |
| `id` | `uuid` | `PRIMARY KEY`, references `auth.users(id)` `ON DELETE CASCADE` | ID unik pengguna, sinkron langsung dengan user Supabase Auth. |
| `phone` | `text` | Nullable | Nomor telepon pengguna (format internasional e.g. `+6281234567890`). |
| `full_name` | `text` | Nullable | Nama lengkap pasien sesuai kartu identitas. |
| `email` | `text` | Nullable | Alamat email kontak pengguna. |
| `auth_email` | `text` | Nullable | Email identitas login Supabase Auth (e.g. `081234567890@kedota.local`). |
| `pin_hash` | `text` | Nullable | Hash SHA-256 dari 6-digit PIN keamanan pengguna. |
| `birth_date` | `date` | Nullable | Tanggal lahir pengguna (`YYYY-MM-DD`). |
| `gender` | `text` | Check in (`Laki-laki`, `Perempuan`, `Lainnya`) | Jenis kelamin pengguna. |
| `signup_method` | `text` | `NOT NULL DEFAULT 'phone'`, Check in (`phone`, `google`, `apple`) | Jalur pendaftaran awal akun pengguna. |
| `status` | `text` | `NOT NULL DEFAULT 'active'`, Check in (`active`, `deactivated`, `recycled`) | Status akun pengguna. |
| `is_profile_complete` | `boolean` | `NOT NULL DEFAULT false` | Status apakah pengguna sudah menyelesaikan onboarding & form profil. |
| `medical_code` | `text` | `UNIQUE` where `medical_code IS NOT NULL` | Kode unik Rekam Medis Elektronik (format: `KDT-XXXXXXXXXXXX`). |
| `email_verified` | `boolean` | `NOT NULL DEFAULT false` | Status apakah alamat email telah lolos verifikasi OTP. |
| `profile_photo_url` | `text` | Nullable | URL publik foto profil di Supabase Storage (`profile-photos`). |
| `nik` | `text` | Nullable | 16-digit Nomor Induk Kependudukan (KTP) pasien. |
| `address` | `text` | Nullable | Alamat tempat tinggal pasien. |
| `last_login_at` | `timestamptz` | Nullable | Waktu terakhir kali pengguna login ke aplikasi. |
| `phone_changed_at` | `timestamptz` | Nullable | Waktu terakhir kali nomor telepon diubah. |
| `email_changed_at` | `timestamptz` | Nullable | Waktu terakhir kali alamat email diubah. |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | Waktu pembuatan data profil. |
| `updated_at` | `timestamptz` | `NOT NULL DEFAULT now()` | Waktu pembaruan data profil (diupdate otomatis oleh trigger). |

---

### B. Tabel `public.appointments` (39 Kolom)
Tabel utama untuk seluruh transaksi janji temu, reservasi fisioterapi, evaluasi medis, dan pembayaran.

| Nama Kolom | Tipe Data PostgreSQL | Constraint & Default | Keterangan & Deskripsi |
| :--- | :--- | :--- | :--- |
| `id` | `uuid` | `PRIMARY KEY DEFAULT gen_random_uuid()` | ID unik janji temu. |
| `booker_id` | `uuid` | `NOT NULL`, references `auth.users(id)` `ON DELETE CASCADE` | ID pengguna yang membuat pesanan reservasi. |
| `patient_is_self` | `boolean` | `NOT NULL DEFAULT true` | `true` jika reservasi untuk diri sendiri, `false` jika untuk orang lain/keluarga. |
| `patient_nik` | `text` | Nullable | NIK KTP pasien penerima terapi. |
| `patient_medical_code`| `text` | Nullable | Kode rekam medis pasien penerima terapi. |
| `patient_full_name` | `text` | Nullable | Nama lengkap pasien penerima terapi. |
| `patient_birth_date` | `date` | Nullable | Tanggal lahir pasien (`YYYY-MM-DD`). |
| `patient_phone` | `text` | Nullable | Nomor telepon aktif pasien. |
| `patient_gender` | `text` | Nullable | Jenis kelamin pasien. |
| `patient_complaint` | `text` | Nullable | Keluhan atau sakit utama yang dialami pasien. |
| `service_type` | `text` | `NOT NULL`, Check in (`Klinik`, `Home Care`) | Tipe layanan fisioterapi yang dipilih. |
| `clinic_name` | `text` | Nullable | Nama klinik cabang jika tipe layanan `Klinik`. |
| `address` | `text` | Nullable | Alamat tujuan terapi jika tipe layanan `Home Care`. |
| `therapist_name` | `text` | Nullable | Nama terapis fisioterapi yang ditugaskan. |
| `therapist_gender_preference` | `text` | Nullable | Preferensi gender terapis (`Laki-laki`, `Perempuan`, `Bebas`). |
| `therapist_availability_requested` | `text` | Nullable | Preferensi jam ketersediaan terapis yang diajukan. |
| `appointment_date` | `date` | `NOT NULL` | Tanggal janji temu terapi (`YYYY-MM-DD`). |
| `appointment_time` | `time` | `NOT NULL` | Waktu jam janji temu terapi (`HH:MM:SS`). |
| `session_count` | `integer` | `NOT NULL DEFAULT 1`, Check in (`1`, `3`, `6`, `9`) | Jumlah sesi dalam paket terapi. |
| `appointment_status`| `text` | `NOT NULL DEFAULT 'upcoming'`, Check in (`upcoming`, `completed`, `expired`, `cancelled`) | Status jalannya janji temu. |
| `payment_plan` | `text` | `NOT NULL DEFAULT 'full'`, Check in (`full`, `deposit`) | Skema pembayaran: bayar penuh (`full`) atau DP (`deposit`). |
| `payment_method` | `text` | Nullable | Metode pembayaran (Transfer Bank, QRIS, GoPay, Tunai, dll). |
| `payment_status` | `text` | `NOT NULL DEFAULT 'pending'`, Check in (`paid`, `pending`, `failed`, `expired`) | Status pelunasan transaksi. |
| `base_price` | `bigint` | `NOT NULL DEFAULT 0` | Harga dasar paket fisioterapi dalam Rupiah. |
| `travel_fee` | `bigint` | `NOT NULL DEFAULT 0` | Ongkos biaya perjalanan untuk Home Care dalam Rupiah. |
| `discount_amount` | `bigint` | `NOT NULL DEFAULT 0` | Nilai potongan kupon/promo dalam Rupiah. |
| `discount_code` | `text` | Nullable | Kode voucher diskon yang digunakan (e.g. `NEWCLINIC10`). |
| `discount_percent` | `integer` | `NOT NULL DEFAULT 0`, Check between `0` and `100` | Persentase diskon yang diberikan (0 - 100%). |
| `total_amount` | `bigint` | `NOT NULL DEFAULT 0` | Total nominal harga yang harus dibayar pasien. |
| `amount_due` | `bigint` | `NOT NULL DEFAULT 0` | Sisa nominal tagihan yang belum dibayar (pada skema deposit). |
| `booking_code` | `text` | `UNIQUE` where `booking_code IS NOT NULL AND booking_code <> ''` | Kode booking kanonikal EMR (format: `EMR-YYYYMMDD-XXXX`). |
| `clinical_note` | `text` | Nullable | Catatan rekam medis & diagnosa klinis pasca-terapi. |
| `vas_score` | `integer` | Nullable, Check between `0` and `10` | Skor skala nyeri VAS (0: tidak nyeri s/d 10: nyeri tak tertahankan). |
| `rom_score` | `integer` | Nullable | Skor evaluasi Range of Motion (kelenturan sendi). |
| `mmt_score` | `integer` | Nullable | Skor Manual Muscle Testing (kekuatan otot, skala 0-5). |
| `odi_score` | `integer` | Nullable, Check between `0` and `50` | Skor disabilitas Oswestry Disability Index (0-50). |
| `therapist_recommendation` | `text` | Nullable | Rekomendasi latihan mandiri di rumah dari fisioterapis. |
| `therapist_sipf` | `text` | Nullable | Nomor Surat Izin Praktik Fisioterapis (SIPF). |
| `therapist_photo_url` | `text` | Nullable | URL foto profil fisioterapis. |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | Waktu pembuatan transaksi reservasi. |
| `updated_at` | `timestamptz` | `NOT NULL DEFAULT now()` | Waktu pembaruan transaksi (diupdate otomatis oleh trigger). |

---

### C. Tabel `public.error_logs` (8 Kolom)
Tabel penampung log error HTTP status 500-599 yang dikirimkan oleh aplikasi mobile client untuk monitoring kehandalan sistem.

| Nama Kolom | Tipe Data PostgreSQL | Constraint & Default | Keterangan & Deskripsi |
| :--- | :--- | :--- | :--- |
| `id` | `bigint` | `GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY` | ID unik log error. |
| `source` | `text` | `NOT NULL` | Sumber client pengirim log (`flutter_client`). |
| `method` | `text` | `NOT NULL` | HTTP Method yang memicu kegagalan (GET, POST, PATCH, dll). |
| `path` | `text` | `NOT NULL` | Path endpoint API yang bermasalah. |
| `status_code` | `integer` | `NOT NULL`, Check between `500` and `599` | Kode status respon server HTTP 5xx. |
| `message` | `text` | Nullable | Deskripsi atau pesan error exception. |
| `platform` | `text` | Nullable | Sistem operasi perangkat client (`android`, `ios`, `web`). |
| `received_at` | `timestamptz` | `NOT NULL DEFAULT now()` | Waktu log dicatat oleh server. |

---

### D. Supabase Storage Bucket: `profile-photos`
- **Bucket ID**: `profile-photos`
- **Visibility**: Public Read (siapa pun dapat mengunduh gambar profil dengan link publik).
- **Maksimum Ukuran File**: 52.428.800 bytes (50 MB).
- **MIME Types yang Diizinkan**: `image/jpeg`, `image/png`.
- **Format Path**: `{userId}/{fileName}` (Row Level Security memastikan hanya user yang memiliki `auth.uid() == userId` yang berhak mengunggah, mengubah, atau menghapus filenya).

---

## 4. Cara Menjalankan & Membuka Swagger UI

Anda dapat langsung melihat visualisasi antarmuka Swagger API ini secara lokal:

1. Buka File Explorer di komputer Anda dan arahkan ke folder:
   `D:\kedotaapp\docs\`
2. Klik dua kali pada file **`swagger-ui.html`**. File ini akan otomatis terbuka di browser favorit Anda.
3. Anda dapat melihat seluruh kelompok endpoint berdasarkan Screen, mengecek skema payload request dan response, serta membaca seluruh dokumentasi kolom database secara interaktif.
