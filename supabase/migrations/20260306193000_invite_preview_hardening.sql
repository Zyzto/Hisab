-- Harden invite preview and align never-expire semantics.
-- 1) Standard invites must not expose preview RPC data.
-- 2) "Never expires" means expires_at = NULL (not 7 days).
-- 3) Reduce preview payload surface.
-- 4) Add bounded limit to preview expenses.

DROP FUNCTION IF EXISTS public.create_invite(UUID, TEXT, TEXT, TEXT, INT, TEXT, TEXT);

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

  -- NULL / blank means "never expires".
  IF p_expires_in IS NULL OR NULLIF(TRIM(p_expires_in), '') IS NULL THEN
    v_expires_at := NULL;
  ELSE
    v_expires_at := now() + p_expires_in::interval;
  END IF;

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

DROP FUNCTION IF EXISTS public.get_invite_preview_group(TEXT);
CREATE OR REPLACE FUNCTION public.get_invite_preview_group(p_token TEXT)
RETURNS TABLE(
  invite_id UUID,
  invite_access_mode TEXT,
  group_id UUID,
  group_name TEXT,
  group_currency_code TEXT,
  group_settlement_method TEXT,
  group_treasurer_participant_id UUID,
  group_allow_member_settle_for_others BOOLEAN,
  group_created_at TIMESTAMPTZ,
  group_updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    gi.id,
    COALESCE(gi.access_mode, 'standard') AS invite_access_mode,
    g.id,
    g.name,
    g.currency_code,
    g.settlement_method,
    g.treasurer_participant_id,
    COALESCE(g.allow_member_settle_for_others, false),
    g.created_at,
    g.updated_at
  FROM public.group_invites gi
  JOIN public.groups g ON g.id = gi.group_id
  WHERE gi.token = p_token
    AND COALESCE(gi.access_mode, 'standard') IN ('readonly_join', 'readonly_only')
    AND (gi.expires_at IS NULL OR gi.expires_at > now())
    AND COALESCE(gi.is_active, true)
    AND (gi.max_uses IS NULL OR COALESCE(gi.use_count, 0) < gi.max_uses);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP FUNCTION IF EXISTS public.get_invite_preview_participants(TEXT);
CREATE OR REPLACE FUNCTION public.get_invite_preview_participants(p_token TEXT)
RETURNS TABLE(
  id UUID,
  group_id UUID,
  name TEXT,
  sort_order INT,
  left_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  member_role TEXT
) AS $$
BEGIN
  RETURN QUERY
  WITH invite AS (
    SELECT gi.group_id
    FROM public.group_invites gi
    WHERE gi.token = p_token
      AND COALESCE(gi.access_mode, 'standard') IN ('readonly_join', 'readonly_only')
      AND (gi.expires_at IS NULL OR gi.expires_at > now())
      AND COALESCE(gi.is_active, true)
      AND (gi.max_uses IS NULL OR COALESCE(gi.use_count, 0) < gi.max_uses)
    LIMIT 1
  )
  SELECT
    p.id,
    p.group_id,
    p.name,
    p.sort_order,
    p.left_at,
    p.created_at,
    p.updated_at,
    gm.role AS member_role
  FROM public.participants p
  JOIN invite i ON i.group_id = p.group_id
  LEFT JOIN public.group_members gm
    ON gm.group_id = p.group_id AND gm.participant_id = p.id
  WHERE p.left_at IS NULL
  ORDER BY p.sort_order ASC, p.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP FUNCTION IF EXISTS public.get_invite_preview_expenses(TEXT);
CREATE OR REPLACE FUNCTION public.get_invite_preview_expenses(
  p_token TEXT,
  p_limit INT DEFAULT 200
)
RETURNS TABLE(
  id UUID,
  group_id UUID,
  payer_participant_id UUID,
  amount_cents INT,
  currency_code TEXT,
  exchange_rate DOUBLE PRECISION,
  base_amount_cents INT,
  title TEXT,
  date TIMESTAMPTZ,
  split_type TEXT,
  split_shares_json TEXT,
  type TEXT,
  to_participant_id UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  WITH invite AS (
    SELECT gi.group_id
    FROM public.group_invites gi
    WHERE gi.token = p_token
      AND COALESCE(gi.access_mode, 'standard') IN ('readonly_join', 'readonly_only')
      AND (gi.expires_at IS NULL OR gi.expires_at > now())
      AND COALESCE(gi.is_active, true)
      AND (gi.max_uses IS NULL OR COALESCE(gi.use_count, 0) < gi.max_uses)
    LIMIT 1
  )
  SELECT
    e.id,
    e.group_id,
    e.payer_participant_id,
    e.amount_cents,
    e.currency_code,
    COALESCE(e.exchange_rate, 1.0) AS exchange_rate,
    e.base_amount_cents,
    e.title,
    e.date,
    e.split_type,
    e.split_shares_json,
    e.type,
    e.to_participant_id,
    e.created_at,
    e.updated_at
  FROM public.expenses e
  JOIN invite i ON i.group_id = e.group_id
  ORDER BY e.date DESC, e.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 200), 1), 1000);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.create_invite(UUID, TEXT, TEXT, TEXT, INT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_invite_preview_group(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_invite_preview_participants(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_invite_preview_expenses(TEXT, INT) TO anon, authenticated;
