-- Defense in depth: group_members UPDATE must keep WITH CHECK aligned with USING.
-- Without WITH CHECK, a privileged path could write unexpected role/user_id values.
-- Members still cannot self-promote (USING requires owner/admin).

DROP POLICY IF EXISTS "group_members_update" ON public.group_members;
CREATE POLICY "group_members_update" ON public.group_members
  FOR UPDATE
  USING (public.get_user_role(group_id) IN ('owner', 'admin'))
  WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    AND group_members.role IN ('owner', 'admin', 'member')
  );
