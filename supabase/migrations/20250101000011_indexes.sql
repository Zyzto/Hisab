-- Migration 11: Composite, partial, and FK indexes
-- Based on docs/SUPABASE_SETUP.md Migration 11

CREATE INDEX IF NOT EXISTS idx_expenses_group_id_date_desc ON public.expenses(group_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_participants_group_id_sort_order ON public.participants(group_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_invite_usages_invite_id_accepted_at ON public.invite_usages(invite_id, accepted_at DESC);

CREATE INDEX IF NOT EXISTS idx_expenses_payer_participant_id ON public.expenses(payer_participant_id);
CREATE INDEX IF NOT EXISTS idx_expenses_to_participant_id ON public.expenses(to_participant_id);
CREATE INDEX IF NOT EXISTS idx_group_invites_created_by ON public.group_invites(created_by);
CREATE INDEX IF NOT EXISTS idx_group_members_participant_id ON public.group_members(participant_id);
CREATE INDEX IF NOT EXISTS idx_groups_treasurer_participant_id ON public.groups(treasurer_participant_id);
CREATE INDEX IF NOT EXISTS idx_groups_owner_id ON public.groups(owner_id);
CREATE INDEX IF NOT EXISTS idx_invite_usages_user_id ON public.invite_usages(user_id);
CREATE INDEX IF NOT EXISTS idx_participants_user_id ON public.participants(user_id);
