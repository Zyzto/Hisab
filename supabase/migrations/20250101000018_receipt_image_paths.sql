-- Migration 19: Expense image paths (multiple photos per expense)
-- Based on docs/SUPABASE_SETUP.md Migration 19

ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS image_paths TEXT;
