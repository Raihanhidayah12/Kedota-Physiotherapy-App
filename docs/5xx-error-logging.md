# Done: Send 5xx Log on Client and Server

Hi [nama atasan],

Fitur **Send 5xx log on client and server** sudah selesai diimplementasi dan aktif 100%.

---

## Apa itu 5xx error?

5xx adalah kode error HTTP yang artinya **server yang bermasalah**, bukan user.

| Kode | Artinya |
|------|---------|
| 500 | Server crash / error tak terduga |
| 502 | Server tidak merespons |
| 503 | Server sedang down / overload |
| 504 | Server timeout |

Contoh: user klik login → server sedang down → user dapat pesan error. Tanpa fitur ini, kita tidak tau kejadian itu. Dengan fitur ini, kita langsung dapat catatannya di database.

---

## Kapan fitur ini aktif?

**Setiap saat selama app digunakan.** Tapi hanya bekerja kalau ada error dari server.

Contoh skenario nyata:

- User login gagal karena server down → **log otomatis terkirim**
- User upload foto profil tapi server error → **log otomatis terkirim**
- User buka halaman jadwal tapi database overload → **log otomatis terkirim**
- App crash tak terduga karena respons aneh dari server → **log otomatis terkirim**

Kalau tidak ada error, fitur ini diam saja. Tidak ada pengaruh ke performa app.

---

## Cara kerjanya (alur sederhana)

```
User pakai app
       ↓
App kirim request ke server
       ↓
Server balas dengan error 500/502/503/504/dst
       ↓
App deteksi error → kirim laporan ke Supabase (background, user tidak terasa)
       ↓
Edge Function terima laporan → simpan ke tabel error_logs
       ↓
Tim bisa lihat di Supabase Dashboard kapan saja
```

---

## Yang sudah diimplementasi

### Sisi App (Flutter)

| Bagian | Status |
|--------|--------|
| API call (profile, data) | ✅ Ter-cover |
| Login & Register | ✅ Ter-cover |
| Google Sign-In | ✅ Ter-cover |
| Upload foto profil | ✅ Ter-cover |
| Query database langsung | ✅ Ter-cover |
| Update PIN | ✅ Ter-cover |
| Error tak terduga / app crash | ✅ Ter-cover (global handler) |

### Sisi Server (Supabase)

| Bagian | Status |
|--------|--------|
| Edge Function `client-error-log` | ✅ Aktif |
| Tabel `error_logs` di database | ✅ Sudah di-apply |
| Validasi payload (anti-abuse) | ✅ Ada |
| Keamanan data sensitif | ✅ Tidak ada password/token yang dikirim |

---

## Data yang tersimpan per error

```
method      → POST, GET, PATCH, dll
path        → /auth/v1/signup, /rest/v1/profiles, dll
status_code → 500, 503, 504, dll
message     → pesan error dari server
platform    → android / ios
received_at → 2026-09-22T10:23:00Z
```

Tidak ada data sensitif. Hanya metadata error.

---

## Cara lihat datanya

Buka **Supabase Dashboard → Table Editor → `error_logs`**

Atau jalankan query:

```sql
-- Error terbaru
SELECT * FROM error_logs ORDER BY received_at DESC LIMIT 50;

-- Error paling sering terjadi
SELECT path, status_code, COUNT(*) as total
FROM error_logs
GROUP BY path, status_code
ORDER BY total DESC;

-- Error hari ini
SELECT * FROM error_logs
WHERE received_at >= NOW() - INTERVAL '24 hours'
ORDER BY received_at DESC;
```

---

## File yang dibuat / diubah

| File | Keterangan |
|------|-----------|
| `lib/main.dart` | Global error handler ditambahkan |
| `lib/services/client_error_log_service.dart` | Service pengirim log error |
| `lib/services/supabase_auth_service.dart` | Logging ditambahkan di semua call ke Supabase |
| `supabase/functions/client-error-log/index.ts` | Edge Function penerima log, simpan ke DB |
| `supabase/migrations/20260922000000_create_error_logs.sql` | Tabel `error_logs` (sudah di-apply) |

---

Status: **✅ Selesai dan aktif.**
