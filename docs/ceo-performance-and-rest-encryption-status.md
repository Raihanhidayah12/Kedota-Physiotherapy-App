# Status Tes Performa Aplikasi dan Enkripsi Data

Dokumen ini menjelaskan dua hal: tes performa aplikasi dan perlindungan data
saat aplikasi berkomunikasi dengan server. Bahasanya dibuat sederhana agar
mudah dipakai saat menjelaskan status ke CEO.

## Ringkasan singkat

> Kita sudah membuat beberapa tes otomatis dan menambahkan perlindungan ekstra
> untuk data PIN yang dikirim melalui salah satu jalur server. Tes yang bisa
> dijalankan di komputer sudah lulus. Namun, kita belum mengukur semua hal di
> ponsel sungguhan, seperti baterai dan performa di ponsel lama. Sebelum
> menyatakan semuanya siap, kita juga perlu memastikan pengaturan server sudah
> dipasang dan semua jalur perubahan PIN sudah diperiksa.

## 1. App Performance Test

| Yang diperiksa | Sudah ada? | Penjelasan sederhana |
| --- | --- | --- |
| CPU usage (beban kerja prosesor) | **Sebagian** | Tes menghitung waktu yang dibutuhkan untuk mengerjakan tugas tertentu. Ini membantu melihat apakah tugasnya lambat, tetapi belum menunjukkan persentase pemakaian prosesor aplikasi. |
| Memory usage (pemakaian memori) | **Sebagian** | Tes melihat perubahan pemakaian memori saat aplikasi menahan data sementara. Ini belum mengukur pemakaian memori tertinggi atau memastikan ada/tidaknya kebocoran memori saat aplikasi dipakai. |
| Battery consumption (pemakaian baterai) | **Belum** | Perlu dites di ponsel sungguhan karena hasil baterai dipengaruhi kondisi perangkat, layar, jaringan, dan aplikasi lain. |
| API response handling (penanganan jawaban server) | **Sebagian** | Tes memeriksa apakah aplikasi bisa membaca jawaban server yang berhasil dan menangani contoh error server. Tes ini memakai server tiruan, jadi belum mengukur kecepatan koneksi internet yang sebenarnya. |
| Image loading speed (kecepatan memuat gambar) | **Sebagian** | Tes mengukur saat aplikasi membuka satu gambar yang sudah tersimpan di dalam aplikasi. Gambar dari internet, seperti foto profil, belum diukur. |
| Performance on older devices (performa di ponsel lama) | **Belum dipastikan** | Ada tes beban kerja sederhana di komputer, tetapi itu belum membuktikan aplikasi lancar di ponsel lama. Harus dites langsung di ponsel lama yang masih didukung. |

### Hasil tes otomatis yang pernah dijalankan

Tes terarah terakhir mencatat **25 tes lulus**. Pada satu kali pengujian di
komputer Windows, hasilnya antara lain:

- 20.000 tugas hitung sederhana selesai sekitar 141 ms.
- Saat tes memakai data sementara sebesar 8 MB, pemakaian memori proses naik
  sekitar 8 MB.
- Tes kirim dan baca data terenkripsi dengan server tiruan selesai sekitar
  49 ms.
- Tes membaca contoh jawaban error server selesai sekitar 7 ms.
- Membuka dan membaca logo aplikasi selesai sekitar 33 ms.
- 2.000 tugas enkripsi selesai sekitar 249 ms.

**Catatan:** angka ini adalah hasil tes di komputer, bukan janji kecepatan
aplikasi di ponsel atau di internet. Hasil juga bisa berubah tergantung
perangkat dan kondisi tes.

Untuk melihat cara menjalankan tes dan cara mengukur langsung di ponsel, buka
[panduan tes performa](./app-performance-testing.md).

## 2. REST encrypt/decrypt data in flight

### Maksudnya apa?

Saat aplikasi mengirim data ke server, data dibungkus agar isinya tidak mudah
dibaca. Saat server membalas, aplikasi membuka kembali bungkus tersebut.
Khusus PIN, aplikasi juga memeriksa tanda pengaman untuk mengetahui apakah data
berubah di tengah jalan.

Koneksi aman HTTPS tetap diperlukan. Enkripsi tambahan ini bukan pengganti
HTTPS.

### Yang sudah dibuat

- Aplikasi sudah memiliki fungsi untuk membungkus dan membuka data.
- Jalur **reset PIN melalui Supabase Edge Function** sudah diatur untuk
  mengirim data dalam bentuk terenkripsi.
- Server sudah diatur untuk membuka data yang masuk dan membungkus jawaban
  sukses sebelum mengirimkannya kembali.
- Server menolak request perubahan PIN jika dikirim tanpa bungkus terenkripsi.
- Tes otomatis memeriksa bahwa PIN tidak terlihat pada isi request yang
  dikirim, jawaban sukses bisa dibuka, dan data yang diubah akan terdeteksi.

### Yang masih perlu diperiksa

- **Belum semua jalur perubahan PIN memakai bungkus enkripsi tambahan ini.**
  Jalur ketika pengguna sudah masuk ke akun menggunakan cara lain untuk
  memperbarui PIN.
- **Jawaban error dari server belum dibungkus dengan enkripsi tambahan.**
  Koneksi HTTPS tetap melindungi komunikasi, tetapi perlindungan tambahan pada
  isi data saat ini hanya diterapkan pada request dan jawaban sukses di jalur
  reset PIN tersebut.
- Ada jalur pencatatan error yang juga dikonfigurasi untuk memakai enkripsi.
  Perlu dipastikan server penerima jalur itu bisa membuka datanya.
- Kode aplikasi dan server sudah disiapkan, tetapi itu **belum membuktikan
  perubahan server sudah dipasang di lingkungan yang dipakai aplikasi**.
  Pengaturan rahasia di Supabase harus cocok dengan pengaturan aplikasi.
  Nilai rahasia jangan dimasukkan ke dokumen atau dikirim lewat chat.
- Kunci enkripsi yang ada di aplikasi ponsel bisa saja ditemukan oleh orang
  yang membongkar aplikasi. Karena itu, tetap gunakan HTTPS dan aturan akses
  server yang benar.

### Status singkat

| Bagian | Status |
| --- | --- |
| Fungsi enkripsi dan pembuka data di aplikasi | **Sudah ada** |
| Request reset PIN ke server | **Sudah dibuat terenkripsi di kode; perlu dites setelah server dipasang** |
| Jawaban sukses dari server | **Sudah dibuat terenkripsi di kode; perlu dites setelah server dipasang** |
| Semua jalur perubahan PIN | **Belum semuanya memakai cara enkripsi tambahan yang sama** |
| Jawaban error dari server | **Belum memakai enkripsi tambahan** |
| Semua komunikasi API aplikasi | **Belum; pengamanan tambahan baru untuk jalur tertentu** |

## 3. Cara mudah menjelaskannya ke CEO

Versi singkat yang bisa disampaikan:

> “Kami sudah menambahkan tes performa dasar dan perlindungan tambahan untuk
> data PIN pada jalur reset PIN. Tes otomatis di komputer sudah lulus.
> Pengujian baterai dan ponsel lama masih perlu dilakukan langsung di perangkat
> fisik. Kami juga perlu memastikan pengaturan server sudah aktif dan memeriksa
> jalur perubahan PIN lainnya sebelum menyatakan semua bagian selesai.”

Jika ditanya lebih lanjut:

- **Apakah performa sudah dites?**  
  “Sudah ada tes dasar untuk waktu kerja aplikasi, memori, jawaban server, dan
  gambar lokal. Baterai dan ponsel lama belum dites langsung.”
- **Apakah semua data API sudah dienkripsi?**  
  “Belum semua. Perlindungan tambahan sudah dibuat untuk jalur reset PIN
  tertentu. Semua komunikasi tetap harus menggunakan HTTPS.”
- **Apa langkah berikutnya?**  
  “Pasang dan cocokkan pengaturan rahasia di server, tes reset PIN dari awal
  sampai selesai, lalu ukur aplikasi di ponsel fisik termasuk ponsel lama.”
- **Apakah angka tes komputer adalah hasil untuk pengguna?**  
  “Belum. Angka itu hanya hasil awal di komputer dan tidak bisa dianggap
  sebagai kecepatan di ponsel atau jaringan pengguna.”

## 4. Langkah berikutnya

- [ ] Pastikan jalur perubahan PIN saat pengguna sudah masuk ke akun juga sudah
  ditinjau.
- [ ] Pastikan server pencatat error bisa membaca data terenkripsi yang
  dikirim aplikasi.
- [ ] Pasang pengaturan kunci yang cocok di Supabase dan deploy perubahan
  server ke lingkungan tes.
- [ ] Tes reset PIN dari aplikasi ke server, termasuk jawaban sukses dan
  jawaban error.
- [ ] Ukur pemakaian prosesor, memori, baterai, dan pemuatan gambar internet di
  ponsel sungguhan.
- [ ] Coba alur utama aplikasi di ponsel lama yang masih didukung dan catat
  hasilnya.

