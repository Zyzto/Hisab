-- Compatibility hardening for invite preview expenses image columns.
-- Uses JSONB key lookup to avoid hard references to either legacy
-- (receipt_image_path/receipt_image_paths) or current
-- (image_path/image_paths) column names.

DROP FUNCTION IF EXISTS public.get_invite_preview_expenses(TEXT, INT);

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
  image_path TEXT,
  image_paths TEXT,
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
    COALESCE(
      to_jsonb(e)->>'image_path',
      to_jsonb(e)->>'receipt_image_path'
    ) AS image_path,
    COALESCE(
      to_jsonb(e)->>'image_paths',
      to_jsonb(e)->>'receipt_image_paths'
    ) AS image_paths,
    e.created_at,
    e.updated_at
  FROM public.expenses e
  JOIN invite i ON i.group_id = e.group_id
  ORDER BY e.date DESC, e.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 200), 1), 1000);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.get_invite_preview_expenses(TEXT, INT) TO anon, authenticated;
