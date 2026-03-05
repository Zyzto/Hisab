-- Migration 7: Schema additions – new columns and invite_usages table
-- Based on docs/SUPABASE_SETUP.md Migration 7

ALTER TABLE public.group_invites
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS label TEXT,
  ADD COLUMN IF NOT EXISTS max_uses INT,
  ADD COLUMN IF NOT EXISTS use_count INT DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true NOT NULL;

CREATE TABLE IF NOT EXISTS public.invite_usages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invite_id UUID NOT NULL REFERENCES public.group_invites(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  accepted_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_invite_usages_invite_id ON public.invite_usages(invite_id);
CREATE INDEX IF NOT EXISTS idx_invite_usages_invite_id_accepted_at ON public.invite_usages(invite_id, accepted_at DESC);

ALTER TABLE public.invite_usages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "invite_usages_select_members" ON public.invite_usages
  FOR SELECT USING (
    public.is_group_member((SELECT group_id FROM public.group_invites WHERE id = invite_id))
  );
CREATE POLICY "invite_usages_insert_own" ON public.invite_usages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.participants
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS avatar_id TEXT;

ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS exchange_rate DOUBLE PRECISION DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS base_amount_cents INT;

ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS icon TEXT,
  ADD COLUMN IF NOT EXISTS color INT;

CREATE INDEX IF NOT EXISTS idx_expenses_group_id_date_desc ON public.expenses(group_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_participants_group_id_sort_order ON public.participants(group_id, sort_order);
