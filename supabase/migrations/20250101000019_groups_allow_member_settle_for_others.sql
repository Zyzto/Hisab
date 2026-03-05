-- Migration 20: Groups allow_member_settle_for_others
-- Based on docs/SUPABASE_SETUP.md Migration 20
-- When false (default), only the group owner or the debtor can record a settlement in the app.

ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS allow_member_settle_for_others BOOLEAN DEFAULT false NOT NULL;
