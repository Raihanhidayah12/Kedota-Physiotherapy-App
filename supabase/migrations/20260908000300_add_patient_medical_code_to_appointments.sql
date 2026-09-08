-- Keep existing appointment tables compatible with the current reservation flow.
alter table public.appointments
  add column if not exists patient_is_self boolean not null default true,
  add column if not exists patient_nik text,
  add column if not exists patient_medical_code text,
  add column if not exists patient_full_name text,
  add column if not exists patient_birth_date date,
  add column if not exists patient_phone text,
  add column if not exists patient_gender text,
  add column if not exists clinic_name text,
  add column if not exists service_type text,
  add column if not exists appointment_date date,
  add column if not exists appointment_time time,
  add column if not exists address text,
  add column if not exists therapist_gender_preference text,
  add column if not exists therapist_availability_requested boolean not null default false,
  add column if not exists session_count integer not null default 1,
  add column if not exists payment_method text,
  add column if not exists payment_plan text default 'full',
  add column if not exists payment_status text default 'pending',
  add column if not exists appointment_status text default 'upcoming',
  add column if not exists discount_code text,
  add column if not exists discount_percent integer not null default 0,
  add column if not exists base_price integer not null default 0,
  add column if not exists travel_fee integer not null default 0,
  add column if not exists discount_amount integer not null default 0,
  add column if not exists total_amount integer not null default 0,
  add column if not exists amount_due integer not null default 0,
  add column if not exists patient_complaint text;

comment on column public.appointments.patient_medical_code is
  'Medical code snapshot recorded when the appointment is created';

alter table public.appointments
  drop constraint if exists appointments_payment_plan_check,
  drop constraint if exists appointments_payment_status_check,
  drop constraint if exists appointments_status_check,
  drop constraint if exists appointments_discount_percent_check,
  drop constraint if exists appointments_pricing_non_negative_check;

alter table public.appointments
  add constraint appointments_payment_plan_check
  check (payment_plan in ('full', 'deposit')),
  add constraint appointments_payment_status_check
  check (payment_status in ('pending', 'paid', 'failed', 'expired')),
  add constraint appointments_status_check
  check (appointment_status in ('upcoming', 'completed', 'expired', 'cancelled')),
  add constraint appointments_discount_percent_check
  check (discount_percent between 0 and 100),
  add constraint appointments_pricing_non_negative_check
  check (
    base_price >= 0 and
    travel_fee >= 0 and
    discount_amount >= 0 and
    total_amount >= 0 and
    amount_due >= 0
  );