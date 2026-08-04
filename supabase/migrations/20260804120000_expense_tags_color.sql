-- Custom category accent color (nullable hex, e.g. #E67E22).
ALTER TABLE public.expense_tags
  ADD COLUMN IF NOT EXISTS color TEXT
  CHECK (
    color IS NULL
    OR color ~ '^#[0-9A-Fa-f]{6}$'
  );

COMMENT ON COLUMN public.expense_tags.color IS
  'Optional #RRGGBB accent for custom tags; null uses client hash palette.';
