alter table public.appointments
  add column if not exists discount_code text,
  add column if not exists discount_percent integer not null default 0;

alter table public.appointments
  drop constraint if exists appointments_discount_percent_check;

alter table public.appointments
  add constraint appointments_discount_percent_check
  check (discount_percent between 0 and 100);