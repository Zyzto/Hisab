-- Notify on expense change / member join: actor (creator/editor or joinee) is excluded from
-- push notifications so only other group members receive them.
-- Requires pg_net and vault secret 'service_role_key'. Replace YOUR_SUPABASE_URL with your
-- project URL (Settings > API > Project URL) before applying if not already set.

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION notify_group_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_group_id UUID;
  v_actor_id UUID;
  v_action TEXT;
  v_expense_title TEXT;
  v_amount_cents INTEGER;
  v_currency_code TEXT;
  v_supabase_url TEXT := 'YOUR_SUPABASE_URL';
  v_service_role_key TEXT;
BEGIN
  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  IF v_service_role_key IS NULL THEN
    RAISE LOG 'notify_group_activity: service_role_key not found in vault, skipping';
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'expenses' THEN
    v_group_id := NEW.group_id;
    v_actor_id := auth.uid();
    v_expense_title := NEW.title;
    v_amount_cents := NEW.amount_cents;
    v_currency_code := NEW.currency_code;

    IF TG_OP = 'INSERT' THEN
      v_action := 'expense_created';
    ELSIF TG_OP = 'UPDATE' THEN
      v_action := 'expense_updated';
    END IF;

  ELSIF TG_TABLE_NAME = 'group_members' THEN
    v_group_id := NEW.group_id;
    v_actor_id := NEW.user_id;
    v_action := 'member_joined';
  END IF;

  IF v_action IS NULL OR v_actor_id IS NULL THEN
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
      'currency_code', v_currency_code
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_on_expense_change ON public.expenses;
CREATE TRIGGER notify_on_expense_change
  AFTER INSERT OR UPDATE ON public.expenses
  FOR EACH ROW
  EXECUTE FUNCTION notify_group_activity();

DROP TRIGGER IF EXISTS notify_on_member_join ON public.group_members;
CREATE TRIGGER notify_on_member_join
  AFTER INSERT ON public.group_members
  FOR EACH ROW
  EXECUTE FUNCTION notify_group_activity();
