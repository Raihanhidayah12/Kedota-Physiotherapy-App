-- Booking codes must use EMR-####-########, not the old KDT- sequence format.

CREATE OR REPLACE FUNCTION public.appointment_emr_booking_code(appointment_id uuid)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  hash bigint := 17;
  s text := appointment_id::text;
  i int;
  sequence_part int;
  reference_part int;
BEGIN
  FOR i IN 1..char_length(s) LOOP
    hash := ((hash * 31) + ascii(substr(s, i, 1))) & 2147483647;
  END LOOP;
  sequence_part := 1000 + (hash % 9000);
  reference_part := 10000000 + (hash % 90000000);
  RETURN 'EMR-' || sequence_part::text || '-' || reference_part::text;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_appointment_emr_booking_code()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.id IS NULL THEN
    NEW.id := gen_random_uuid();
  END IF;
  IF NEW.booking_code IS NULL
     OR btrim(NEW.booking_code) = ''
     OR NEW.booking_code ILIKE 'KDT-%' THEN
    NEW.booking_code := public.appointment_emr_booking_code(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_appointment_emr_booking_code ON public.appointments;
CREATE TRIGGER set_appointment_emr_booking_code
  BEFORE INSERT OR UPDATE OF booking_code
  ON public.appointments
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_appointment_emr_booking_code();

ALTER TABLE public.appointments
  ALTER COLUMN booking_code DROP DEFAULT;

UPDATE public.appointments
SET booking_code = public.appointment_emr_booking_code(id)
WHERE booking_code IS NULL
   OR btrim(booking_code) = ''
   OR booking_code ILIKE 'KDT-%';
