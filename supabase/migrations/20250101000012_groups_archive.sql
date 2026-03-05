-- Migration 12: Groups archive (archived_at)
-- Based on docs/SUPABASE_SETUP.md Migration 12

ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;
