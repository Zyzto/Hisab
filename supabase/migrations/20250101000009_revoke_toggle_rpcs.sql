-- Migration 9: revoke_invite and toggle_invite_active RPCs
-- Based on docs/SUPABASE_SETUP.md Migration 9

CREATE OR REPLACE FUNCTION public.revoke_invite(p_invite_id UUID)
RETURNS VOID AS $$
DECLARE
  v_group_id UUID;
  v_user_role TEXT;
BEGIN
  SELECT group_id INTO v_group_id FROM public.group_invites WHERE id = p_invite_id;
  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invite not found';
  END IF;
  SELECT role INTO v_user_role FROM public.group_members
  WHERE group_id = v_group_id AND user_id = auth.uid();
  IF v_user_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can revoke invites';
  END IF;
  UPDATE public.group_invites SET is_active = false WHERE id = p_invite_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE OR REPLACE FUNCTION public.toggle_invite_active(p_invite_id UUID, p_active BOOLEAN)
RETURNS VOID AS $$
DECLARE
  v_group_id UUID;
  v_user_role TEXT;
BEGIN
  SELECT group_id INTO v_group_id FROM public.group_invites WHERE id = p_invite_id;
  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invite not found';
  END IF;
  SELECT role INTO v_user_role FROM public.group_members
  WHERE group_id = v_group_id AND user_id = auth.uid();
  IF v_user_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can toggle invites';
  END IF;
  UPDATE public.group_invites SET is_active = p_active WHERE id = p_invite_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

ALTER FUNCTION public.get_invite_by_token(TEXT) SET search_path = '';
ALTER FUNCTION public.accept_invite(TEXT, UUID, TEXT) SET search_path = '';
DO $$ BEGIN ALTER FUNCTION public.create_invite(UUID, TEXT, TEXT, TEXT, INT, TEXT) SET search_path = ''; EXCEPTION WHEN undefined_function THEN NULL; END $$;
