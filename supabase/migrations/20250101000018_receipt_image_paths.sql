-- Migration 19: Receipt image paths (multiple photos per expense)
-- Based on docs/SUPABASE_SETUP.md Migration 19

ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS receipt_image_paths TEXT;
