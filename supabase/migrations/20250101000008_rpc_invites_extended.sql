-- Migration 8: Extended create_invite and accept_invite with label, max_uses, use_count
-- Based on docs/SUPABASE_SETUP.md Migration 8

DROP FUNCTION IF EXISTS public.create_invite(UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.create_invite(
  p_group_id UUID,
  p_invitee_email TEXT DEFAULT NULL,
  p_role TEXT DEFAULT 'member',
  p_label TEXT DEFAULT NULL,
  p_max_uses INT DEFAULT NULL,
  p_expires_in TEXT DEFAULT NULL
)
RETURNS TABLE(id UUID, token TEXT) AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_token TEXT;
  v_invite_id UUID;
  v_expires_at TIMESTAMPTZ;
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

  v_expires_at := now() + COALESCE(p_expires_in::interval, interval '7 days');

  INSERT INTO public.group_invites (
    group_id, token, invitee_email, role, expires_at,
    created_by, label, max_uses, use_count, is_active
  )
  VALUES (
    p_group_id, v_token, p_invitee_email, p_role, v_expires_at,
    v_user_id, p_label, p_max_uses, 0, true
  )
  RETURNING group_invites.id INTO v_invite_id;

  RETURN QUERY SELECT v_invite_id, v_token;
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
  v_use_count INT;
  v_max_uses INT;
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

  IF (v_invite.is_active IS NOT NULL AND NOT v_invite.is_active) THEN
    RAISE EXCEPTION 'Invite is not active';
  END IF;

  v_use_count := COALESCE(v_invite.use_count, 0);
  v_max_uses := v_invite.max_uses;
  IF v_max_uses IS NOT NULL AND v_use_count >= v_max_uses THEN
    RAISE EXCEPTION 'Invite has reached max uses';
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

  INSERT INTO public.invite_usages (invite_id, user_id)
  VALUES (v_invite.id, v_user_id);

  UPDATE public.group_invites
  SET use_count = v_use_count + 1
  WHERE id = v_invite.id;

  IF v_max_uses IS NOT NULL AND (v_use_count + 1) >= v_max_uses THEN
    DELETE FROM public.group_invites WHERE id = v_invite.id;
  END IF;

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER FUNCTION public.create_invite(UUID, TEXT, TEXT, TEXT, INT, TEXT) SET search_path = '';
ALTER FUNCTION public.accept_invite(TEXT, UUID, TEXT) SET search_path = '';
