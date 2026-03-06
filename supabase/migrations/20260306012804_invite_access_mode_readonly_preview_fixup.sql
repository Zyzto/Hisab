-- Fixup migration for invite access mode RPC signatures.

DROP FUNCTION IF EXISTS public.get_invite_by_token(TEXT);
DROP FUNCTION IF EXISTS public.create_invite(UUID, TEXT, TEXT, TEXT, INT, TEXT);

CREATE OR REPLACE FUNCTION public.create_invite(
  p_group_id UUID,
  p_invitee_email TEXT DEFAULT NULL,
  p_role TEXT DEFAULT 'member',
  p_label TEXT DEFAULT NULL,
  p_max_uses INT DEFAULT NULL,
  p_expires_in TEXT DEFAULT NULL,
  p_access_mode TEXT DEFAULT 'standard'
)
RETURNS TABLE(id UUID, token TEXT) AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_token TEXT;
  v_invite_id UUID;
  v_expires_at TIMESTAMPTZ;
  v_access_mode TEXT;
BEGIN
  v_user_id := auth.uid();

  SELECT gm.role INTO v_user_role FROM public.group_members gm
  WHERE gm.group_id = p_group_id AND gm.user_id = v_user_id;

  IF v_user_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can create invites';
  END IF;

  v_access_mode := COALESCE(NULLIF(TRIM(p_access_mode), ''), 'standard');
  IF v_access_mode NOT IN ('standard', 'readonly_join', 'readonly_only') THEN
    RAISE EXCEPTION 'Invalid invite access mode';
  END IF;

  v_token := pg_catalog.encode(extensions.gen_random_bytes(18), 'base64');
  v_token := replace(replace(replace(v_token, '+', ''), '/', ''), '=', '');
  v_token := substr(v_token, 1, 24);

  v_expires_at := now() + COALESCE(p_expires_in::interval, interval '7 days');

  INSERT INTO public.group_invites (
    group_id, token, invitee_email, role, expires_at,
    created_by, label, max_uses, use_count, is_active, access_mode
  )
  VALUES (
    p_group_id, v_token, p_invitee_email, p_role, v_expires_at,
    v_user_id, p_label, p_max_uses, 0, true, v_access_mode
  )
  RETURNING group_invites.id INTO v_invite_id;

  RETURN QUERY SELECT v_invite_id, v_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE OR REPLACE FUNCTION public.get_invite_by_token(p_token TEXT)
RETURNS TABLE(
  invite_id UUID,
  group_id UUID,
  token TEXT,
  invitee_email TEXT,
  role TEXT,
  created_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_by UUID,
  label TEXT,
  max_uses INT,
  use_count INT,
  is_active BOOLEAN,
  access_mode TEXT,
  group_name TEXT,
  group_currency_code TEXT,
  group_created_at TIMESTAMPTZ,
  group_updated_at TIMESTAMPTZ
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
    gi.created_by,
    gi.label,
    gi.max_uses,
    COALESCE(gi.use_count, 0) AS use_count,
    COALESCE(gi.is_active, true) AS is_active,
    COALESCE(gi.access_mode, 'standard') AS access_mode,
    g.name AS group_name,
    g.currency_code AS group_currency_code,
    g.created_at AS group_created_at,
    g.updated_at AS group_updated_at
  FROM public.group_invites gi
  JOIN public.groups g ON g.id = gi.group_id
  WHERE gi.token = p_token
    AND (gi.expires_at IS NULL OR gi.expires_at > now())
    AND COALESCE(gi.is_active, true)
    AND (gi.max_uses IS NULL OR COALESCE(gi.use_count, 0) < gi.max_uses);
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
    AND (expires_at IS NULL OR expires_at > now());

  IF v_invite IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired invite';
  END IF;

  IF (v_invite.is_active IS NOT NULL AND NOT v_invite.is_active) THEN
    RAISE EXCEPTION 'Invite is not active';
  END IF;

  IF COALESCE(v_invite.access_mode, 'standard') = 'readonly_only' THEN
    RAISE EXCEPTION 'Invite is read-only';
  END IF;

  v_use_count := COALESCE(v_invite.use_count, 0);
  v_max_uses := v_invite.max_uses;
  IF v_max_uses IS NOT NULL AND v_use_count >= v_max_uses THEN
    RAISE EXCEPTION 'Invite has reached max uses';
  END IF;

  v_group_id := v_invite.group_id;

  IF EXISTS (
    SELECT 1
    FROM public.group_members
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
    SELECT u.raw_user_meta_data->>'avatar_id'
      INTO v_avatar_id
      FROM auth.users u
      WHERE u.id = v_user_id;
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
      (
        SELECT COALESCE(MAX(sort_order), 0) + 1
        FROM public.participants
        WHERE group_id = v_group_id
      ),
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

CREATE OR REPLACE FUNCTION public.accept_invite(p_token TEXT)
RETURNS UUID AS $$
BEGIN
  RETURN public.accept_invite(p_token, NULL, NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DO $$ BEGIN
  ALTER FUNCTION public.get_invite_by_token(TEXT) SET search_path = '';
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$ BEGIN
  ALTER FUNCTION public.create_invite(UUID, TEXT, TEXT, TEXT, INT, TEXT, TEXT) SET search_path = '';
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$ BEGIN
  ALTER FUNCTION public.accept_invite(TEXT, UUID, TEXT) SET search_path = '';
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$ BEGIN
  ALTER FUNCTION public.accept_invite(TEXT) SET search_path = '';
EXCEPTION WHEN undefined_function THEN NULL;
END $$;
