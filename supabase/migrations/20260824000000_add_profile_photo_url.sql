alter table public.profiles
add column if not exists profile_photo_url text;

comment on column public.profiles.profile_photo_url is
  'URL foto profil pengguna, dapat berasal dari OAuth atau diubah dari halaman pengaturan';

insert into storage.buckets (id, name, public)
values ('profile-photos', 'profile-photos', true)
on conflict (id) do update set public = true;

create policy "Users can view profile photos"
on storage.objects for select
to public
using (bucket_id = 'profile-photos');

create policy "Users can upload their profile photo"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "Users can update their profile photo"
on storage.objects for update
to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);
