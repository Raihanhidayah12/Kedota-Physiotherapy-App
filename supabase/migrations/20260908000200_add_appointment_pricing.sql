alter table public.appointments
  add column if not exists base_price integer not null default 0,
  add column if not exists travel_fee integer not null default 0,
  add column if not exists discount_amount integer not null default 0,
  add column if not exists total_amount integer not null default 0,
  add column if not exists amount_due integer not null default 0;

alter table public.appointments
  drop constraint if exists appointments_pricing_non_negative_check;

alter table public.appointments
  add constraint appointments_pricing_non_negative_check
  check (
    base_price >= 0 and
    travel_fee >= 0 and
    discount_amount >= 0 and
    total_amount >= 0 and
    amount_due >= 0
  );