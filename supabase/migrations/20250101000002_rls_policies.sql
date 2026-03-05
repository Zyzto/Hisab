-- Migration 2: RLS policies
-- Based on docs/SUPABASE_SETUP.md Migration 2

CREATE OR REPLACE FUNCTION public.get_user_role(p_group_id UUID)
RETURNS TEXT AS $$
  SELECT role FROM public.group_members
  WHERE group_id = p_group_id AND user_id = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_group_member(p_group_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = auth.uid()
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE;

ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.telemetry ENABLE ROW LEVEL SECURITY;

CREATE POLICY "groups_select" ON public.groups
  FOR SELECT USING (
    public.is_group_member(id)
    OR (SELECT auth.uid()) = owner_id
  );

CREATE POLICY "groups_insert_authenticated" ON public.groups
  FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND owner_id = (SELECT auth.uid()));

CREATE POLICY "groups_update_owner_admin" ON public.groups
  FOR UPDATE USING (public.get_user_role(id) IN ('owner', 'admin'));

CREATE POLICY "groups_delete_owner" ON public.groups
  FOR DELETE USING (public.get_user_role(id) = 'owner');

CREATE POLICY "group_members_select" ON public.group_members
  FOR SELECT USING (public.is_group_member(group_id));

CREATE POLICY "group_members_insert" ON public.group_members
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      user_id = (SELECT auth.uid())
      AND role = 'owner'
      AND (SELECT g.owner_id FROM public.groups g WHERE g.id = group_id) = (SELECT auth.uid())
    )
  );

CREATE POLICY "group_members_update" ON public.group_members
  FOR UPDATE USING (public.get_user_role(group_id) IN ('owner', 'admin'));

CREATE POLICY "group_members_delete" ON public.group_members
  FOR DELETE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR user_id = (SELECT auth.uid())
  );

CREATE POLICY "participants_select" ON public.participants
  FOR SELECT USING (public.is_group_member(group_id));

CREATE POLICY "participants_insert" ON public.participants
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_add_participant FROM public.groups g WHERE g.id = group_id) = true
    )
    OR (SELECT g.owner_id FROM public.groups g WHERE g.id = group_id) = (SELECT auth.uid())
  );

CREATE POLICY "participants_update" ON public.participants
  FOR UPDATE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_change_settings FROM public.groups g WHERE g.id = group_id) = true
    )
  );

CREATE POLICY "participants_delete" ON public.participants
  FOR DELETE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (
        (SELECT g.allow_member_add_participant FROM public.groups g WHERE g.id = group_id) = true
        OR (SELECT g.allow_member_change_settings FROM public.groups g WHERE g.id = group_id) = true
      )
    )
  );

CREATE POLICY "expenses_select" ON public.expenses
  FOR SELECT USING (public.is_group_member(group_id));

CREATE POLICY "expenses_insert" ON public.expenses
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_add_expense FROM public.groups g WHERE g.id = group_id) = true
    )
  );

CREATE POLICY "expenses_update" ON public.expenses
  FOR UPDATE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_add_expense FROM public.groups g WHERE g.id = group_id) = true
    )
  );

CREATE POLICY "expenses_delete" ON public.expenses
  FOR DELETE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_add_expense FROM public.groups g WHERE g.id = group_id) = true
    )
  );

CREATE POLICY "expense_tags_select" ON public.expense_tags
  FOR SELECT USING (public.is_group_member(group_id));

CREATE POLICY "expense_tags_insert" ON public.expense_tags
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_change_settings FROM public.groups g WHERE g.id = group_id) = true
    )
  );

CREATE POLICY "expense_tags_update" ON public.expense_tags
  FOR UPDATE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_change_settings FROM public.groups g WHERE g.id = group_id) = true
    )
  );

CREATE POLICY "expense_tags_delete" ON public.expense_tags
  FOR DELETE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_change_settings FROM public.groups g WHERE g.id = group_id) = true
    )
  );

CREATE POLICY "group_invites_select_members" ON public.group_invites
  FOR SELECT USING (public.is_group_member(group_id));

CREATE POLICY "group_invites_insert" ON public.group_invites
  FOR INSERT WITH CHECK (public.get_user_role(group_id) IN ('owner', 'admin'));

CREATE POLICY "group_invites_delete" ON public.group_invites
  FOR DELETE USING (public.get_user_role(group_id) IN ('owner', 'admin'));

CREATE POLICY "telemetry_insert" ON public.telemetry
  FOR INSERT WITH CHECK (true);
