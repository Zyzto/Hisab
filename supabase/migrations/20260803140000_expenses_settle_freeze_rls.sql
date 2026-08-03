-- Harden expenses RLS for settlement freeze, archive, and transfer settle rules.
-- Aligns with client: freeze blocks new expenses; archive blocks mutations;
-- transfers require owner / debtor / allow_member_settle_for_others (not admin-only).

CREATE OR REPLACE FUNCTION public.expense_group_not_archived(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.groups g
    WHERE g.id = p_group_id
      AND g.archived_at IS NULL
  );
$$;

CREATE OR REPLACE FUNCTION public.expense_group_allows_insert(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.groups g
    WHERE g.id = p_group_id
      AND g.archived_at IS NULL
      AND g.settlement_freeze_at IS NULL
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_group_expense(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    public.get_user_role(p_group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(p_group_id) = 'member'
      AND EXISTS (
        SELECT 1
        FROM public.groups g
        WHERE g.id = p_group_id
          AND g.allow_member_add_expense = true
      )
    );
$$;

-- Transfer settle permission + integrity (amount, parties, active participants).
CREATE OR REPLACE FUNCTION public.transfer_expense_allowed(
  p_group_id uuid,
  p_type text,
  p_amount_cents int,
  p_payer_participant_id uuid,
  p_to_participant_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    CASE
      WHEN p_type IS DISTINCT FROM 'transfer' THEN true
      WHEN p_amount_cents IS NULL OR p_amount_cents <= 0 THEN false
      WHEN p_to_participant_id IS NULL THEN false
      WHEN p_payer_participant_id IS NULL THEN false
      WHEN p_payer_participant_id = p_to_participant_id THEN false
      WHEN NOT EXISTS (
        SELECT 1
        FROM public.participants p
        WHERE p.id = p_payer_participant_id
          AND p.group_id = p_group_id
          AND p.left_at IS NULL
      ) THEN false
      WHEN NOT EXISTS (
        SELECT 1
        FROM public.participants p
        WHERE p.id = p_to_participant_id
          AND p.group_id = p_group_id
          AND p.left_at IS NULL
      ) THEN false
      WHEN public.get_user_role(p_group_id) = 'owner' THEN true
      WHEN EXISTS (
        SELECT 1
        FROM public.groups g
        WHERE g.id = p_group_id
          AND g.allow_member_settle_for_others = true
      ) THEN true
      WHEN EXISTS (
        SELECT 1
        FROM public.participants p
        WHERE p.id = p_payer_participant_id
          AND p.group_id = p_group_id
          AND p.user_id = (SELECT auth.uid())
          AND p.left_at IS NULL
      ) THEN true
      ELSE false
    END;
$$;

REVOKE ALL ON FUNCTION public.expense_group_not_archived(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.expense_group_allows_insert(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_write_group_expense(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.transfer_expense_allowed(uuid, text, int, uuid, uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.expense_group_not_archived(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expense_group_allows_insert(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_group_expense(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_expense_allowed(uuid, text, int, uuid, uuid) TO authenticated;

DROP POLICY IF EXISTS "expenses_insert" ON public.expenses;
CREATE POLICY "expenses_insert" ON public.expenses
  FOR INSERT WITH CHECK (
    public.expense_group_allows_insert(group_id)
    AND public.can_write_group_expense(group_id)
    AND public.transfer_expense_allowed(
      group_id,
      type,
      amount_cents,
      payer_participant_id,
      to_participant_id
    )
  );

DROP POLICY IF EXISTS "expenses_update" ON public.expenses;
CREATE POLICY "expenses_update" ON public.expenses
  FOR UPDATE
  USING (
    public.expense_group_not_archived(group_id)
    AND public.can_write_group_expense(group_id)
  )
  WITH CHECK (
    public.expense_group_not_archived(group_id)
    AND public.can_write_group_expense(group_id)
    AND public.transfer_expense_allowed(
      group_id,
      type,
      amount_cents,
      payer_participant_id,
      to_participant_id
    )
  );

DROP POLICY IF EXISTS "expenses_delete" ON public.expenses;
CREATE POLICY "expenses_delete" ON public.expenses
  FOR DELETE USING (
    public.expense_group_not_archived(group_id)
    AND public.can_write_group_expense(group_id)
  );
