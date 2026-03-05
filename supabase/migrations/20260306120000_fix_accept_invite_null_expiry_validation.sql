-- Fix invite acceptance for never-expiring invites.
-- Align accept_invite token validation with get_invite_by_token:
-- - accepts expires_at IS NULL
-- - pre-filters inactive / max-used invites

CREATE OR REPLACE FUNCTION public.accept_invite(
  p_token TEXT
)
RETURNS UUID AS $$
DECLARE
  v_invite RECORD;
  v_user_id UUID;
  v_group_id UUID;
  v_participant_id UUID;
  v_display_name TEXT;
  v_next_order INT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_invite FROM public.group_invites
  WHERE group_invites.token = p_token
    AND (expires_at IS NULL OR expires_at > now())
    AND (is_active IS NULL OR is_active = true)
    AND (max_uses IS NULL OR COALESCE(use_count, 0) < max_uses);

  IF v_invite IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired invite';
  END IF;

  v_group_id := v_invite.group_id;

  IF EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = v_group_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Already a member of this group';
  END IF;

  v_display_name := COALESCE(
    (SELECT raw_user_meta_data->>'display_name' FROM auth.users WHERE id = v_user_id),
    (SELECT email FROM auth.users WHERE id = v_user_id),
    'User'
  );

  SELECT id INTO v_participant_id FROM public.participants
  WHERE group_id = v_group_id AND user_id = v_user_id
  LIMIT 1;

  IF v_participant_id IS NULL THEN
    SELECT COALESCE(MAX(sort_order), 0) + 1 INTO v_next_order
    FROM public.participants WHERE group_id = v_group_id;

    INSERT INTO public.participants (group_id, name, sort_order, user_id)
    VALUES (v_group_id, v_display_name, v_next_order, v_user_id)
    RETURNING id INTO v_participant_id;
  END IF;

  INSERT INTO public.group_members (group_id, user_id, role, participant_id)
  VALUES (v_group_id, v_user_id, v_invite.role, v_participant_id);

  DELETE FROM public.group_invites WHERE id = v_invite.id;

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

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
  v_reuse_participant_id UUID;
  v_display_name TEXT;
  v_avatar_id TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_invite FROM public.group_invites
  WHERE group_invites.token = p_token
    AND (expires_at IS NULL OR expires_at > now())
    AND (is_active IS NULL OR is_active = true)
    AND (max_uses IS NULL OR COALESCE(use_count, 0) < max_uses);

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

  IF EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = v_group_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Already a member of this group';
  END IF;

  SELECT id INTO v_reuse_participant_id FROM public.participants
  WHERE group_id = v_group_id AND user_id = v_user_id AND left_at IS NOT NULL
  LIMIT 1;

  IF v_reuse_participant_id IS NOT NULL THEN
    SELECT COALESCE(
      NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), ''),
      NULLIF(TRIM(u.raw_user_meta_data->>'name'), ''),
      u.email
    ) INTO v_display_name FROM auth.users u WHERE u.id = v_user_id;
    SELECT u.raw_user_meta_data->>'avatar_id' INTO v_avatar_id FROM auth.users u WHERE u.id = v_user_id;

    UPDATE public.participants
    SET left_at = NULL,
        name = COALESCE(NULLIF(TRIM(v_display_name), ''), name),
        avatar_id = COALESCE(v_avatar_id, avatar_id),
        updated_at = now()
    WHERE id = v_reuse_participant_id AND group_id = v_group_id;

    p_participant_id := v_reuse_participant_id;
  ELSIF p_new_participant_name IS NOT NULL AND p_new_participant_name != '' THEN
    INSERT INTO public.participants (group_id, name, sort_order, user_id)
    VALUES (
      v_group_id,
      p_new_participant_name,
      (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM public.participants WHERE group_id = v_group_id),
      v_user_id
    )
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
