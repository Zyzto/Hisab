-- Backward-compatibility: some projects may not yet have
-- groups.allow_member_settle_for_others. Avoid hard-referencing it in
-- get_invite_preview_group so readonly invite preview still works.

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
    COALESCE((to_jsonb(g)->>'allow_member_settle_for_others')::boolean, false),
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

GRANT EXECUTE ON FUNCTION public.get_invite_preview_group(TEXT) TO anon, authenticated;
