-- Include expense_id in notify_group_activity pg_net payload for send-notification.
-- Additive only: CREATE OR REPLACE function; no data changes.

CREATE OR REPLACE FUNCTION public.notify_group_activity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_group_id UUID;
  v_actor_id UUID;
  v_action TEXT;
  v_expense_title TEXT;
  v_amount_cents INTEGER;
  v_currency_code TEXT;
  v_expense_id UUID;
  v_supabase_url TEXT := 'https://jscbwcerbsdewsczadjf.supabase.co';
  v_service_role_key TEXT;
  v_is_personal BOOLEAN;
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
    v_expense_id := NEW.id;

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

  SELECT is_personal INTO v_is_personal FROM public.groups WHERE id = v_group_id;
  IF v_is_personal THEN
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
      'expense_id', v_expense_id
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    )
  );

  RETURN NEW;
END;
$function$;
