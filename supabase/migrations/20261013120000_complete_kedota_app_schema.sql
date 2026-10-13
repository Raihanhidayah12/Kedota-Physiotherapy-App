-- Core database objects used by the Kedota Flutter application.
-- Apply only after reviewing the target project's existing schema and data.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  phone text,
  full_name text,
  email text,
  auth_email text,
  pin_hash text,
  birth_date date,
  gender text,
  signup_method text not null default 'phone',
  status text not null default 'active',
  is_profile_complete boolean not null default false,
  medical_code text,
  email_verified boolean not null default false,
  profile_photo_url text,
  nik text,
  address text,
  last_login_at timestamptz,
  phone_changed_at timestamptz,
  email_changed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_signup_method_check
    check (signup_method in ('phone', 'google', 'apple')),
  constraint profiles_status_check
    check (status in ('active', 'deactivated', 'recycled')),
  constraint profiles_gender_check
    check (gender is null or gender in ('Laki-laki', 'Perempuan', 'Lainnya'))
);

alter table public.profiles
  add column if not exists phone text,
  add column if not exists full_name text,
  add column if not exists email text,
  add column if not exists auth_email text,
  add column if not exists pin_hash text,
  add column if not exists birth_date date,
  add column if not exists gender text,
  add column if not exists signup_method text default 'phone',
  add column if not exists status text default 'active',
  add column if not exists is_profile_complete boolean default false,
  add column if not exists medical_code text,
  add column if not exists email_verified boolean default false,
  add column if not exists profile_photo_url text,
  add column if not exists nik text,
  add column if not exists address text,
  add column if not exists last_login_at timestamptz,
  add column if not exists phone_changed_at timestamptz,
  add column if not exists email_changed_at timestamptz,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

create unique index if not exists profiles_medical_code_unique
  on public.profiles (medical_code) where medical_code is not null;
create index if not exists profiles_auth_email_idx
  on public.profiles (lower(auth_email)) where auth_email is not null;
create index if not exists profiles_email_idx
  on public.profiles (lower(email)) where email is not null;
create index if not exists profiles_status_idx on public.profiles (status);

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  booker_id uuid not null references auth.users (id) on delete cascade,
  patient_is_self boolean not null default true,
  patient_nik text,
  patient_medical_code text,
  patient_full_name text,
  patient_birth_date date,
  patient_phone text,
  patient_gender text,
  patient_complaint text,
  service_type text not null,
  clinic_name text,
  address text,
  therapist_name text,
  therapist_gender_preference text,
  therapist_availability_requested text,
  appointment_date date not null,
  appointment_time time not null,
  session_count integer not null default 1,
  appointment_status text not null default 'upcoming',
  payment_plan text not null default 'full',
  payment_method text,
  payment_status text not null default 'pending',
  base_price bigint not null default 0,
  travel_fee bigint not null default 0,
  discount_amount bigint not null default 0,
  discount_code text,
  discount_percent integer not null default 0,
  total_amount bigint not null default 0,
  amount_due bigint not null default 0,
  booking_code text,
  clinical_note text,
  vas_score integer,
  rom_score integer,
  mmt_score integer,
  odi_score integer,
  therapist_recommendation text,
  therapist_sipf text,
  therapist_photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint appointments_service_type_check
    check (service_type in ('Klinik', 'Home Care')),
  constraint appointments_status_check
    check (appointment_status in ('upcoming', 'completed', 'expired', 'cancelled')),
  constraint appointments_payment_plan_check
    check (payment_plan in ('full', 'deposit')),
  constraint appointments_payment_status_check
    check (payment_status in ('paid', 'pending', 'failed', 'expired')),
  constraint appointments_session_count_check
    check (session_count in (1, 3, 6, 9)),
  constraint appointments_discount_percent_check
    check (discount_percent between 0 and 100),
  constraint appointments_vas_score_check
    check (vas_score is null or vas_score between 0 and 10),
  constraint appointments_odi_score_check
    check (odi_score is null or odi_score between 0 and 50)
);

alter table public.appointments
  add column if not exists booker_id uuid references auth.users (id) on delete cascade,
  add column if not exists patient_is_self boolean default true,
  add column if not exists patient_nik text,
  add column if not exists patient_medical_code text,
  add column if not exists patient_full_name text,
  add column if not exists patient_birth_date date,
  add column if not exists patient_phone text,
  add column if not exists patient_gender text,
  add column if not exists patient_complaint text,
  add column if not exists service_type text,
  add column if not exists clinic_name text,
  add column if not exists address text,
  add column if not exists therapist_name text,
  add column if not exists therapist_gender_preference text,
  add column if not exists therapist_availability_requested text,
  add column if not exists appointment_date date,
  add column if not exists appointment_time time,
  add column if not exists session_count integer default 1,
  add column if not exists appointment_status text default 'upcoming',
  add column if not exists payment_plan text default 'full',
  add column if not exists payment_method text,
  add column if not exists payment_status text default 'pending',
  add column if not exists base_price bigint default 0,
  add column if not exists travel_fee bigint default 0,
  add column if not exists discount_amount bigint default 0,
  add column if not exists discount_code text,
  add column if not exists discount_percent integer default 0,
  add column if not exists total_amount bigint default 0,
  add column if not exists amount_due bigint default 0,
  add column if not exists booking_code text,
  add column if not exists clinical_note text,
  add column if not exists vas_score integer,
  add column if not exists rom_score integer,
  add column if not exists mmt_score integer,
  add column if not exists odi_score integer,
  add column if not exists therapist_recommendation text,
  add column if not exists therapist_sipf text,
  add column if not exists therapist_photo_url text,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

create index if not exists appointments_booker_date_idx
  on public.appointments (booker_id, appointment_date desc, appointment_time);
create index if not exists appointments_schedule_lookup_idx
  on public.appointments (appointment_date, appointment_time, service_type, clinic_name)
  where appointment_status <> 'cancelled';
create unique index if not exists appointments_booking_code_unique
  on public.appointments (booking_code)
  where booking_code is not null and booking_code <> '';

create or replace function public.prevent_appointment_slot_conflict()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.appointment_status = 'cancelled' then
    return new;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      new.appointment_date::text || '|' ||
      new.appointment_time::text || '|' ||
      new.service_type || '|' ||
      coalesce(new.clinic_name, ''),
      0
    )
  );

  if exists (
    select 1
    from public.appointments as conflicting
    where conflicting.id is distinct from new.id
      and conflicting.appointment_date = new.appointment_date
      and conflicting.appointment_time = new.appointment_time
      and conflicting.service_type = new.service_type
      and coalesce(conflicting.clinic_name, '') = coalesce(new.clinic_name, '')
      and conflicting.appointment_status <> 'cancelled'
  ) then
    raise exception 'Appointment slot is unavailable' using errcode = '23505';
  end if;

  return new;
end;
$$;

drop trigger if exists appointments_prevent_slot_conflict on public.appointments;
create trigger appointments_prevent_slot_conflict
before insert or update of appointment_date, appointment_time, service_type,
  clinic_name, appointment_status
on public.appointments
for each row execute function public.prevent_appointment_slot_conflict();

create table if not exists public.error_logs (
  id bigint generated by default as identity primary key,
  source text not null,
  method text not null,
  path text not null,
  status_code integer not null check (status_code between 500 and 599),
  message text,
  platform text,
  received_at timestamptz not null default now()
);

alter table public.error_logs enable row level security;
revoke all on public.error_logs from anon, authenticated;
grant all on public.error_logs to service_role;
create index if not exists error_logs_received_at_idx
  on public.error_logs (received_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists appointments_set_updated_at on public.appointments;
create trigger appointments_set_updated_at
before update on public.appointments
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.appointments enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
for select to authenticated
using (id = (select auth.uid()));

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
for insert to authenticated
with check (id = (select auth.uid()));

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

drop policy if exists appointments_select_own on public.appointments;
create policy appointments_select_own on public.appointments
for select to authenticated
using (booker_id = (select auth.uid()));

drop policy if exists appointments_insert_own on public.appointments;
create policy appointments_insert_own on public.appointments
for insert to authenticated
with check (booker_id = (select auth.uid()));

drop policy if exists appointments_update_own on public.appointments;
create policy appointments_update_own on public.appointments
for update to authenticated
using (booker_id = (select auth.uid()))
with check (booker_id = (select auth.uid()));

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.appointments to authenticated;

drop function if exists public.expire_overdue_appointments();

create or replace function public.expire_overdue_appointments()
returns setof public.appointments
language sql
security invoker
set search_path = ''
as $$
  update public.appointments as appointment
  set appointment_status = 'expired'
  where appointment.booker_id = (select auth.uid())
    and appointment.appointment_status = 'upcoming'
    and (appointment.appointment_date + appointment.appointment_time)
      < (now() - interval '15 minutes')
  returning appointment.*;
$$;

create or replace function public.reschedule_appointment(
  p_appointment_id uuid,
  p_appointment_date date,
  p_appointment_time time
)
returns public.appointments
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_appointment public.appointments;
  updated_appointment public.appointments;
  scheduled_at timestamp;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select appointment.*
  into current_appointment
  from public.appointments as appointment
  where appointment.id = p_appointment_id
    and appointment.booker_id = auth.uid()
  for update;

  if not found then
    raise exception 'Appointment not found' using errcode = 'P0002';
  end if;

  if current_appointment.appointment_status not in ('upcoming', 'expired') then
    raise exception 'Appointment cannot be rescheduled' using errcode = '22023';
  end if;

  scheduled_at := current_appointment.appointment_date
    + current_appointment.appointment_time;

  if current_appointment.payment_status = 'paid' then
    if current_appointment.appointment_status <> 'expired'
      or now() < scheduled_at
      or now() > scheduled_at + interval '24 hours' then
      raise exception 'Paid appointment is outside the reschedule window'
        using errcode = '22023';
    end if;
  elsif scheduled_at - now() < interval '24 hours' then
    raise exception 'Appointment must be rescheduled at least 24 hours ahead'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.appointments as conflicting
    where conflicting.id <> p_appointment_id
      and conflicting.appointment_date = p_appointment_date
      and conflicting.appointment_time = p_appointment_time
      and conflicting.service_type = current_appointment.service_type
      and coalesce(conflicting.clinic_name, '') =
        coalesce(current_appointment.clinic_name, '')
      and conflicting.appointment_status <> 'cancelled'
  ) then
    raise exception 'Appointment slot is unavailable' using errcode = '23505';
  end if;

  update public.appointments
  set appointment_date = p_appointment_date,
      appointment_time = p_appointment_time,
      appointment_status = 'upcoming'
  where id = p_appointment_id
  returning * into updated_appointment;

  return updated_appointment;
end;
$$;

create or replace function public.settle_appointment_payment(
  p_appointment_id uuid,
  p_payment_method text
)
returns public.appointments
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_appointment public.appointments;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  update public.appointments
  set payment_status = 'paid',
      payment_method = p_payment_method,
      amount_due = 0
  where id = p_appointment_id
    and booker_id = auth.uid()
    and payment_status = 'pending'
  returning * into updated_appointment;

  if not found then
    raise exception 'Pending appointment payment not found' using errcode = 'P0002';
  end if;

  return updated_appointment;
end;
$$;

revoke all on function public.expire_overdue_appointments() from public, anon;
revoke all on function public.reschedule_appointment(uuid, date, time) from public, anon;
revoke all on function public.settle_appointment_payment(uuid, text) from public, anon;
grant execute on function public.expire_overdue_appointments() to authenticated;
grant execute on function public.reschedule_appointment(uuid, date, time) to authenticated;
grant execute on function public.settle_appointment_payment(uuid, text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-photos',
  'profile-photos',
  true,
  52428800,
  array['image/jpeg', 'image/png']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists profile_photos_public_read on storage.objects;
create policy profile_photos_public_read on storage.objects
for select to anon, authenticated
using (bucket_id = 'profile-photos');

drop policy if exists profile_photos_insert_own on storage.objects;
create policy profile_photos_insert_own on storage.objects
for insert to authenticated
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists profile_photos_update_own on storage.objects;
create policy profile_photos_update_own on storage.objects
for update to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists profile_photos_delete_own on storage.objects;
create policy profile_photos_delete_own on storage.objects
for delete to authenticated
using (
  bucket_id = 'profile-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
