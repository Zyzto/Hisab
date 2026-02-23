-- Add group setting: when false, members can only create/update expenses as themselves (payer = their participant).
-- Owners and admins are unrestricted.

ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS allow_expense_as_other_participant BOOLEAN DEFAULT true NOT NULL;

-- Helper: current user's participant_id in the given group (NULL if not a member or no participant linked).
CREATE OR REPLACE FUNCTION public.get_my_participant_id(p_group_id UUID)
RETURNS UUID AS $$
  SELECT participant_id FROM public.group_members
  WHERE group_id = p_group_id AND user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Tighten expenses INSERT: members must use self as payer when allow_expense_as_other_participant is false.
DROP POLICY IF EXISTS "expenses_insert" ON public.expenses;
CREATE POLICY "expenses_insert" ON public.expenses
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_add_expense FROM public.groups g WHERE g.id = group_id) = true
      AND (
        (SELECT g.allow_expense_as_other_participant FROM public.groups g WHERE g.id = group_id) = true
        OR payer_participant_id = public.get_my_participant_id(group_id)
      )
    )
  );

-- Tighten expenses UPDATE: same payer restriction for members (WITH CHECK on the new row).
DROP POLICY IF EXISTS "expenses_update" ON public.expenses;
CREATE POLICY "expenses_update" ON public.expenses
  FOR UPDATE
  USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_add_expense FROM public.groups g WHERE g.id = group_id) = true
    )
  )
  WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_add_expense FROM public.groups g WHERE g.id = group_id) = true
      AND (
        (SELECT g.allow_expense_as_other_participant FROM public.groups g WHERE g.id = group_id) = true
        OR payer_participant_id = public.get_my_participant_id(group_id)
      )
    )
  );

-- Harden function search_path (match other functions in project).
ALTER FUNCTION public.get_my_participant_id(UUID) SET search_path = '';
