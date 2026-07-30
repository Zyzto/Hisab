-- Revamp notify_group_activity:
-- - Skip image-only / updated_at-only expense UPDATEs (create-with-photos double notify)
-- - Include group_name in pg_net payload
-- - Support expense DELETE → expense_deleted
-- - Skip when group is missing (CASCADE from group delete) or personal

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
      -- Skip non-content updates (e.g. receipt image paths after create).
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

  SELECT g.name, g.is_personal
    INTO v_group_name, v_is_personal
  FROM public.groups g
  WHERE g.id = v_group_id;

  -- Missing group (CASCADE delete) or personal group: do not notify.
  IF v_group_name IS NULL OR v_is_personal IS TRUE THEN
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

DROP TRIGGER IF EXISTS notify_on_expense_change ON public.expenses;
CREATE TRIGGER notify_on_expense_change
  AFTER INSERT OR UPDATE OR DELETE ON public.expenses
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_group_activity();
