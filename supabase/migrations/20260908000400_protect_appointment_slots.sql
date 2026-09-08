-- Allow clients to check occupied slots without exposing appointment details.
drop policy if exists "Users can read active appointment slots" on public.appointments;
create policy "Users can read active appointment slots"
  on public.appointments for select
  using (appointment_status = 'upcoming');

-- Prevent two users from booking the same active appointment slot concurrently.
drop index if exists public.appointments_active_slot_unique_idx;
create unique index if not exists appointments_active_slot_unique_idx
  on public.appointments (
    service_type,
    clinic_name,
    appointment_date,
    appointment_time
  )
  where appointment_status = 'upcoming';