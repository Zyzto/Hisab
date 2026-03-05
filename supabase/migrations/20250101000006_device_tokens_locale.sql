-- Migration 6b: device_tokens locale for localized push notifications
-- Based on docs/SUPABASE_SETUP.md Migration 6b
-- (Migration 6 – notification triggers via pg_net/vault – is skipped for local testing)

ALTER TABLE public.device_tokens
  ADD COLUMN IF NOT EXISTS locale TEXT;
