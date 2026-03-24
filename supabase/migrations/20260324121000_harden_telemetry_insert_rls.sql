-- Harden telemetry insert policy to avoid always-true RLS checks.
-- Keep anonymous ingestion possible with strict payload constraints.

DROP POLICY IF EXISTS "telemetry_insert" ON public.telemetry;

CREATE POLICY "telemetry_insert" ON public.telemetry
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    length(btrim(event)) >= 1
    AND length(event) <= 120
    AND event ~ '^[a-z0-9]+([._:-][a-z0-9]+)*$'
    AND "timestamp" IS NOT NULL
    AND "timestamp" >= (now() - interval '1 day')
    AND "timestamp" <= (now() + interval '5 minutes')
    AND (
      data IS NULL
      OR (
        jsonb_typeof(data) = 'object'
        AND pg_column_size(data) <= 16384
      )
    )
  );
