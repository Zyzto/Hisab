-- Token-scoped preview RPCs for non-member invite previews.

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
    AND (gi.expires_at IS NULL OR gi.expires_at > now())
    AND COALESCE(gi.is_active, true)
    AND (gi.max_uses IS NULL OR COALESCE(gi.use_count, 0) < gi.max_uses);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE OR REPLACE FUNCTION public.get_invite_preview_participants(p_token TEXT)
RETURNS TABLE(
  id UUID,
  group_id UUID,
  name TEXT,
  sort_order INT,
  user_id UUID,
  avatar_id TEXT,
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
    p.user_id,
    p.avatar_id,
    p.left_at,
    p.created_at,
    p.updated_at,
    gm.role AS member_role
  FROM public.participants p
  JOIN invite i ON i.group_id = p.group_id
  LEFT JOIN public.group_members gm
    ON gm.group_id = p.group_id AND gm.participant_id = p.id
  ORDER BY p.sort_order ASC, p.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE OR REPLACE FUNCTION public.get_invite_preview_expenses(p_token TEXT)
RETURNS TABLE(
  id UUID,
  group_id UUID,
  payer_participant_id UUID,
  amount_cents INT,
  currency_code TEXT,
  exchange_rate DOUBLE PRECISION,
  base_amount_cents INT,
  title TEXT,
  description TEXT,
  date TIMESTAMPTZ,
  split_type TEXT,
  split_shares_json TEXT,
  type TEXT,
  to_participant_id UUID,
  tag TEXT,
  line_items_json TEXT,
  receipt_image_path TEXT,
  receipt_image_paths TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  WITH invite AS (
    SELECT gi.group_id
    FROM public.group_invites gi
    WHERE gi.token = p_token
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
    e.description,
    e.date,
    e.split_type,
    e.split_shares_json,
    e.type,
    e.to_participant_id,
    e.tag,
    e.line_items_json,
    e.receipt_image_path,
    e.receipt_image_paths,
    e.created_at,
    e.updated_at
  FROM public.expenses e
  JOIN invite i ON i.group_id = e.group_id
  ORDER BY e.date DESC, e.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.get_invite_preview_group(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_invite_preview_participants(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_invite_preview_expenses(TEXT) TO anon, authenticated;
