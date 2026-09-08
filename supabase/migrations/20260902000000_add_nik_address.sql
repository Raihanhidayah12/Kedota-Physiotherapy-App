-- Tambah kolom NIK dan alamat ke tabel profiles
alter table public.profiles
  add column if not exists nik text,
  add column if not exists address text,
  add column if not exists medical_code text;

comment on column public.profiles.nik is
  'Nomor Induk Kependudukan (16 digit)';

comment on column public.profiles.address is
  'Alamat lengkap pengguna';

comment on column public.profiles.medical_code is
  'Kode nomor medis yang dibuat dan dikelola oleh Kedota';
