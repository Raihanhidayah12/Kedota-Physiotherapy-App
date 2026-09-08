-- Reservation records and patient snapshot data.
create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  booker_id uuid not null references auth.users(id) on delete cascade,
  patient_is_self boolean not null default true,
  patient_nik text not null check (patient_nik ~ '^[0-9]{16}$'),
  patient_medical_code text not null,
  patient_full_name text not null,
  patient_birth_date date not null,
  patient_phone text not null,
  patient_gender text not null,
  clinic_name text,
  service_type text not null,
  appointment_date date not null,
  appointment_time time not null,
  address text,
  therapist_gender_preference text,
  therapist_availability_requested boolean not null default false,
  session_count integer not null default 1 check (session_count between 1 and 20),
  payment_plan text not null default 'full'
    check (payment_plan in ('full', 'deposit')),
  payment_method text,
  payment_status text not null default 'pending'
    check (payment_status in ('pending', 'paid', 'failed', 'expired')),
  appointment_status text not null default 'upcoming'
    check (appointment_status in ('upcoming', 'completed', 'expired', 'cancelled')),
  patient_complaint text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists appointments_booker_id_idx
  on public.appointments (booker_id);
create index if not exists appointments_date_idx
  on public.appointments (appointment_date, appointment_time);

alter table public.appointments enable row level security;

drop policy if exists "Users can read their appointments" on public.appointments;
create policy "Users can read their appointments"
  on public.appointments for select
  using (auth.uid() = booker_id);

drop policy if exists "Users can create their appointments" on public.appointments;
create policy "Users can create their appointments"
  on public.appointments for insert
  with check (auth.uid() = booker_id);

drop policy if exists "Users can update their appointments" on public.appointments;
create policy "Users can update their appointments"
  on public.appointments for update
  using (auth.uid() = booker_id)
  with check (auth.uid() = booker_id);

drop policy if exists "Users can cancel their appointments" on public.appointments;
create policy "Users can cancel their appointments"
  on public.appointments for delete
  using (auth.uid() = booker_id);
