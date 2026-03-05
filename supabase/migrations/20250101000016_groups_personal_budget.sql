-- Migration 16: Groups personal and budget columns
-- Based on docs/SUPABASE_SETUP.md Migration 16

ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS is_personal BOOLEAN DEFAULT false NOT NULL;

ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS budget_amount_cents INT;
