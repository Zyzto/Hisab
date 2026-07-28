-- Fix owner bootstrap INSERT into group_members.
--
-- In RLS WITH CHECK expressions, bare `role` is ambiguous with the SQL session
-- role name (usually 'authenticated'), so `role = 'owner'` is always false.
-- Qualify the column as group_members.role.
--
-- Also allow group owners to SELECT group_members rows so PostgREST
-- Prefer: return=representation (INSERT ... RETURNING) succeeds on bootstrap.

DROP POLICY IF EXISTS "group_members_insert" ON public.group_members;
CREATE POLICY "group_members_insert" ON public.group_members
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      user_id = (SELECT auth.uid())
      AND group_members.role = 'owner'
      AND public.is_group_owner(group_id)
    )
  );

DROP POLICY IF EXISTS "group_members_select" ON public.group_members;
CREATE POLICY "group_members_select" ON public.group_members
  FOR SELECT USING (
    public.is_group_member(group_id)
    OR public.is_group_owner(group_id)
  );
