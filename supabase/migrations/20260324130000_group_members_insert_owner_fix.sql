-- Ensure owner bootstrap insert into group_members is allowed reliably.
-- In local/dev runs, policy subqueries that depend on RLS can be brittle.
-- Use a SECURITY DEFINER owner check for a stable insert policy.

CREATE OR REPLACE FUNCTION public.is_group_owner(p_group_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.groups g
    WHERE g.id = p_group_id
      AND g.owner_id = (SELECT auth.uid())
  );
$$;

REVOKE ALL ON FUNCTION public.is_group_owner(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_group_owner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_group_owner(UUID) TO anon;

DROP POLICY IF EXISTS "group_members_insert" ON public.group_members;
CREATE POLICY "group_members_insert" ON public.group_members
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      user_id = (SELECT auth.uid())
      AND role = 'owner'
      AND public.is_group_owner(group_id)
    )
  );
