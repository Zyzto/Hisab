-- Migration 3: RPC functions
-- Based on docs/SUPABASE_SETUP.md Migration 3

CREATE OR REPLACE FUNCTION public.get_invite_by_token(p_token TEXT)
RETURNS TABLE(
  invite_id UUID,
  group_id UUID,
  token TEXT,
  invitee_email TEXT,
  role TEXT,
  created_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  group_name TEXT,
  group_currency_code TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    gi.id AS invite_id,
    gi.group_id,
    gi.token,
    gi.invitee_email,
    gi.role,
    gi.created_at,
    gi.expires_at,
    g.name AS group_name,
    g.currency_code AS group_currency_code
  FROM public.group_invites gi
  JOIN public.groups g ON g.id = gi.group_id
  WHERE gi.token = p_token
    AND gi.expires_at > now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.accept_invite(
  p_token TEXT,
  p_participant_id UUID DEFAULT NULL,
  p_new_participant_name TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_invite RECORD;
  v_user_id UUID;
  v_group_id UUID;
  v_new_participant_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_invite FROM public.group_invites
  WHERE group_invites.token = p_token AND expires_at > now();

  IF v_invite IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired invite';
  END IF;

  v_group_id := v_invite.group_id;

  IF EXISTS (SELECT 1 FROM public.group_members WHERE group_id = v_group_id AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'Already a member of this group';
  END IF;

  IF p_new_participant_name IS NOT NULL AND p_new_participant_name != '' THEN
    INSERT INTO public.participants (group_id, name, sort_order)
    VALUES (v_group_id, p_new_participant_name,
      (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM public.participants WHERE group_id = v_group_id))
    RETURNING id INTO v_new_participant_id;
    p_participant_id := v_new_participant_id;
  END IF;

  INSERT INTO public.group_members (group_id, user_id, role, participant_id)
  VALUES (v_group_id, v_user_id, v_invite.role, p_participant_id);

  DELETE FROM public.group_invites WHERE id = v_invite.id;

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.transfer_ownership(
  p_group_id UUID,
  p_new_owner_member_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_current_member RECORD;
  v_new_owner_member RECORD;
BEGIN
  v_user_id := auth.uid();

  SELECT * INTO v_current_member FROM public.group_members
  WHERE group_id = p_group_id AND user_id = v_user_id AND role = 'owner';

  IF v_current_member IS NULL THEN
    RAISE EXCEPTION 'Only the owner can transfer ownership';
  END IF;

  SELECT * INTO v_new_owner_member FROM public.group_members
  WHERE id = p_new_owner_member_id AND group_id = p_group_id;

  IF v_new_owner_member IS NULL THEN
    RAISE EXCEPTION 'Member not found in this group';
  END IF;

  UPDATE public.group_members SET role = 'admin' WHERE id = v_current_member.id;
  UPDATE public.group_members SET role = 'owner' WHERE id = v_new_owner_member.id;
  UPDATE public.groups SET owner_id = v_new_owner_member.user_id WHERE id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.leave_group(p_group_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_member RECORD;
  v_oldest_member RECORD;
BEGIN
  v_user_id := auth.uid();

  SELECT * INTO v_member FROM public.group_members
  WHERE group_id = p_group_id AND user_id = v_user_id;

  IF v_member IS NULL THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;

  IF v_member.role = 'owner' THEN
    SELECT * INTO v_oldest_member FROM public.group_members
    WHERE group_id = p_group_id AND user_id != v_user_id
    ORDER BY joined_at ASC
    LIMIT 1;

    IF v_oldest_member IS NOT NULL THEN
      UPDATE public.group_members SET role = 'owner' WHERE id = v_oldest_member.id;
      UPDATE public.groups SET owner_id = v_oldest_member.user_id WHERE id = p_group_id;
    ELSE
      UPDATE public.groups SET owner_id = NULL WHERE id = p_group_id;
    END IF;
  END IF;

  DELETE FROM public.group_members WHERE id = v_member.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.kick_member(
  p_group_id UUID,
  p_member_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_kicker_role TEXT;
  v_target RECORD;
BEGIN
  v_user_id := auth.uid();

  SELECT role INTO v_kicker_role FROM public.group_members
  WHERE group_id = p_group_id AND user_id = v_user_id;

  IF v_kicker_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can kick members';
  END IF;

  SELECT * INTO v_target FROM public.group_members
  WHERE id = p_member_id AND group_id = p_group_id;

  IF v_target IS NULL THEN
    RAISE EXCEPTION 'Member not found in this group';
  END IF;

  IF v_target.role = 'owner' THEN
    RAISE EXCEPTION 'Cannot kick the owner';
  END IF;

  DELETE FROM public.group_members WHERE id = p_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.update_member_role(
  p_group_id UUID,
  p_member_id UUID,
  p_role TEXT
)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_target RECORD;
BEGIN
  v_user_id := auth.uid();

  IF p_role NOT IN ('admin', 'member') THEN
    RAISE EXCEPTION 'Invalid role. Must be admin or member';
  END IF;

  SELECT role INTO v_user_role FROM public.group_members
  WHERE group_id = p_group_id AND user_id = v_user_id;

  IF v_user_role != 'owner' THEN
    RAISE EXCEPTION 'Only the owner can change roles';
  END IF;

  SELECT * INTO v_target FROM public.group_members
  WHERE id = p_member_id AND group_id = p_group_id;

  IF v_target IS NULL THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  IF v_target.role = 'owner' THEN
    RAISE EXCEPTION 'Cannot change owner role directly. Use transfer_ownership instead';
  END IF;

  UPDATE public.group_members SET role = p_role WHERE id = p_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.assign_participant(
  p_group_id UUID,
  p_member_id UUID,
  p_participant_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_participant RECORD;
BEGIN
  v_user_id := auth.uid();

  SELECT role INTO v_user_role FROM public.group_members
  WHERE group_id = p_group_id AND user_id = v_user_id;

  IF v_user_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can assign participants';
  END IF;

  SELECT * INTO v_participant FROM public.participants
  WHERE id = p_participant_id AND group_id = p_group_id;

  IF v_participant IS NULL THEN
    RAISE EXCEPTION 'Participant not found in this group';
  END IF;

  UPDATE public.group_members SET participant_id = p_participant_id
  WHERE id = p_member_id AND group_id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.create_invite(
  p_group_id UUID,
  p_invitee_email TEXT DEFAULT NULL,
  p_role TEXT DEFAULT 'member'
)
RETURNS TABLE(id UUID, token TEXT) AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_token TEXT;
  v_invite_id UUID;
BEGIN
  v_user_id := auth.uid();

  SELECT gm.role INTO v_user_role FROM public.group_members gm
  WHERE gm.group_id = p_group_id AND gm.user_id = v_user_id;

  IF v_user_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can create invites';
  END IF;

  v_token := pg_catalog.encode(extensions.gen_random_bytes(18), 'base64');
  v_token := replace(replace(replace(v_token, '+', ''), '/', ''), '=', '');
  v_token := substr(v_token, 1, 24);

  INSERT INTO public.group_invites (group_id, token, invitee_email, role, expires_at)
  VALUES (p_group_id, v_token, p_invitee_email, p_role, now() + interval '7 days')
  RETURNING group_invites.id INTO v_invite_id;

  RETURN QUERY SELECT v_invite_id, v_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
