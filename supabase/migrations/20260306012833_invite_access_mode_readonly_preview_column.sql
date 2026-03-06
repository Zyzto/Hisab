-- Adds invite access mode column and constraints.

ALTER TABLE public.group_invites
  ADD COLUMN IF NOT EXISTS access_mode TEXT;

UPDATE public.group_invites
SET access_mode = 'standard'
WHERE access_mode IS NULL OR access_mode = '';

ALTER TABLE public.group_invites
  ALTER COLUMN access_mode SET DEFAULT 'standard';

ALTER TABLE public.group_invites
  ALTER COLUMN access_mode SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'group_invites_access_mode_check'
      AND conrelid = 'public.group_invites'::regclass
  ) THEN
    ALTER TABLE public.group_invites
      ADD CONSTRAINT group_invites_access_mode_check
      CHECK (access_mode IN ('standard', 'readonly_join', 'readonly_only'));
  END IF;
END $$;
