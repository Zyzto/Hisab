-- Migration 1: Core schema – tables, indexes, triggers
-- Based on docs/SUPABASE_SETUP.md Migration 1

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE public.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 200),
  currency_code TEXT NOT NULL CHECK (length(currency_code) = 3),
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  settlement_method TEXT DEFAULT 'greedy',
  treasurer_participant_id UUID,
  settlement_freeze_at TIMESTAMPTZ,
  settlement_snapshot_json TEXT,
  allow_member_add_expense BOOLEAN DEFAULT true NOT NULL,
  allow_member_add_participant BOOLEAN DEFAULT true NOT NULL,
  allow_member_change_settings BOOLEAN DEFAULT true NOT NULL,
  require_participant_assignment BOOLEAN DEFAULT false NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE public.participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100),
  sort_order INT DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.groups
  ADD CONSTRAINT fk_groups_treasurer_participant
  FOREIGN KEY (treasurer_participant_id) REFERENCES public.participants(id) ON DELETE SET NULL;

CREATE TABLE public.group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member')),
  participant_id UUID REFERENCES public.participants(id) ON DELETE SET NULL,
  joined_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  UNIQUE(group_id, user_id)
);

CREATE TABLE public.expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  payer_participant_id UUID NOT NULL REFERENCES public.participants(id) ON DELETE CASCADE,
  amount_cents INT NOT NULL,
  currency_code TEXT NOT NULL CHECK (length(currency_code) = 3),
  title TEXT NOT NULL CHECK (length(title) >= 1 AND length(title) <= 500),
  description TEXT,
  date TIMESTAMPTZ NOT NULL,
  split_type TEXT NOT NULL CHECK (split_type IN ('equal', 'parts', 'amounts')),
  split_shares_json TEXT,
  type TEXT DEFAULT 'expense' NOT NULL CHECK (type IN ('expense', 'income', 'transfer')),
  to_participant_id UUID REFERENCES public.participants(id) ON DELETE SET NULL,
  tag TEXT,
  line_items_json TEXT,
  image_path TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE public.expense_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  label TEXT NOT NULL CHECK (length(label) >= 1 AND length(label) <= 100),
  icon_name TEXT NOT NULL CHECK (length(icon_name) >= 1 AND length(icon_name) <= 80),
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE public.group_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  invitee_email TEXT,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE public.telemetry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event TEXT NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT now(),
  data JSONB
);

CREATE INDEX idx_group_members_group_id ON public.group_members(group_id);
CREATE INDEX idx_group_members_user_id ON public.group_members(user_id);
CREATE INDEX idx_group_invites_group_id ON public.group_invites(group_id);
CREATE INDEX idx_participants_group_id ON public.participants(group_id);
CREATE INDEX idx_participants_group_id_sort_order ON public.participants(group_id, sort_order);
CREATE INDEX idx_expenses_group_id ON public.expenses(group_id);
CREATE INDEX idx_expenses_group_id_date_desc ON public.expenses(group_id, date DESC);
CREATE INDEX idx_expense_tags_group_id ON public.expense_tags(group_id);

CREATE TRIGGER set_groups_updated_at
  BEFORE UPDATE ON public.groups
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_participants_updated_at
  BEFORE UPDATE ON public.participants
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_expenses_updated_at
  BEFORE UPDATE ON public.expenses
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_expense_tags_updated_at
  BEFORE UPDATE ON public.expense_tags
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
