-- Claim FCM tokens to a single user, unique(token), and skip edge notify
-- when the actor is the only group member.

-- 1) Deduplicate shared tokens (keep newest updated_at).
DELETE FROM public.device_tokens d
USING public.device_tokens newer
WHERE d.token = newer.token
  AND d.id <> newer.id
  AND (
    newer.updated_at > d.updated_at
    OR (newer.updated_at = d.updated_at AND newer.id > d.id)
  );

CREATE UNIQUE INDEX IF NOT EXISTS idx_device_tokens_token_unique
  ON public.device_tokens (token);

-- 2) Claim token for the authenticated user (SECURITY DEFINER upsert by token).
CREATE OR REPLACE FUNCTION public.claim_device_token(
  p_token TEXT,
  p_platform TEXT,
  p_locale TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_token IS NULL OR btrim(p_token) = '' THEN
    RAISE EXCEPTION 'token required';
  END IF;
  IF p_platform IS NULL OR p_platform NOT IN ('android', 'ios', 'web') THEN
    RAISE EXCEPTION 'invalid platform';
  END IF;

  -- Unique(token): one device token maps to exactly one user.
  INSERT INTO public.device_tokens (user_id, token, platform, locale, updated_at)
  VALUES (v_uid, p_token, p_platform, p_locale, now())
  ON CONFLICT (token) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        platform = EXCLUDED.platform,
        locale = EXCLUDED.locale,
        updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.claim_device_token(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_device_token(TEXT, TEXT, TEXT) TO authenticated;

-- 3) Skip pg_net when no other members remain to notify.
CREATE OR REPLACE FUNCTION public.notify_group_activity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_row public.expenses%ROWTYPE;
  v_group_id UUID;
  v_actor_id UUID;
  v_action TEXT;
  v_expense_title TEXT;
  v_amount_cents INTEGER;
  v_currency_code TEXT;
  v_expense_id UUID;
  v_group_name TEXT;
  v_supabase_url TEXT := 'https://jscbwcerbsdewsczadjf.supabase.co';
  v_service_role_key TEXT;
  v_is_personal BOOLEAN;
  v_suppress BOOLEAN;
BEGIN
  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  IF v_service_role_key IS NULL THEN
    RAISE LOG 'notify_group_activity: service_role_key not found in vault, skipping';
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'expenses' THEN
    IF TG_OP = 'DELETE' THEN
      v_row := OLD;
      v_action := 'expense_deleted';
    ELSIF TG_OP = 'INSERT' THEN
      v_row := NEW;
      v_action := 'expense_created';
    ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.title IS NOT DISTINCT FROM OLD.title
         AND NEW.amount_cents IS NOT DISTINCT FROM OLD.amount_cents
         AND NEW.currency_code IS NOT DISTINCT FROM OLD.currency_code
         AND NEW.description IS NOT DISTINCT FROM OLD.description
         AND NEW.date IS NOT DISTINCT FROM OLD.date
         AND NEW.payer_participant_id IS NOT DISTINCT FROM OLD.payer_participant_id
         AND NEW.split_type IS NOT DISTINCT FROM OLD.split_type
         AND NEW.split_shares_json IS NOT DISTINCT FROM OLD.split_shares_json
         AND NEW.type IS NOT DISTINCT FROM OLD.type
         AND NEW.to_participant_id IS NOT DISTINCT FROM OLD.to_participant_id
         AND NEW.tag IS NOT DISTINCT FROM OLD.tag
         AND NEW.line_items_json IS NOT DISTINCT FROM OLD.line_items_json
         AND NEW.exchange_rate IS NOT DISTINCT FROM OLD.exchange_rate
         AND NEW.base_amount_cents IS NOT DISTINCT FROM OLD.base_amount_cents
      THEN
        RETURN NEW;
      END IF;
      v_row := NEW;
      v_action := 'expense_updated';
    END IF;

    v_group_id := v_row.group_id;
    v_actor_id := auth.uid();
    v_expense_title := v_row.title;
    v_amount_cents := v_row.amount_cents;
    v_currency_code := v_row.currency_code;
    v_expense_id := v_row.id;

  ELSIF TG_TABLE_NAME = 'group_members' THEN
    v_group_id := NEW.group_id;
    v_actor_id := NEW.user_id;
    v_action := 'member_joined';
  END IF;

  IF v_action IS NULL OR v_actor_id IS NULL THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  -- Bulk import / silent pending_writes push: skip edge notify.
  SELECT active INTO v_suppress
  FROM public.user_notify_suppress
  WHERE user_id = v_actor_id;
  IF COALESCE(v_suppress, FALSE) THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  SELECT g.name, g.is_personal
    INTO v_group_name, v_is_personal
  FROM public.groups g
  WHERE g.id = v_group_id;

  IF v_group_name IS NULL OR v_is_personal IS TRUE THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  -- Avoid edge invocation when actor is the only member.
  IF NOT EXISTS (
    SELECT 1
    FROM public.group_members gm
    WHERE gm.group_id = v_group_id
      AND gm.user_id IS DISTINCT FROM v_actor_id
  ) THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/send-notification',
    body := jsonb_build_object(
      'group_id', v_group_id,
      'actor_user_id', v_actor_id,
      'action', v_action,
      'expense_title', v_expense_title,
      'amount_cents', v_amount_cents,
      'currency_code', v_currency_code,
      'expense_id', v_expense_id,
      'group_name', v_group_name
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    )
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;
