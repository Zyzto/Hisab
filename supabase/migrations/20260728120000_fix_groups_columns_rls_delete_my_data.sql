-- Fix group column drift, align groups/participants UPDATE RLS with app UI,
-- and ship Delete cloud data RPCs (get_delete_my_data_preview / delete_my_data).

-- ---------------------------------------------------------------------------
-- groups.allow_expense_as_other_participant (client + sync already expect it)
-- ---------------------------------------------------------------------------
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS allow_expense_as_other_participant BOOLEAN DEFAULT true NOT NULL;

-- ---------------------------------------------------------------------------
-- groups UPDATE: owner/admin, or member when allow_member_change_settings
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "groups_update_owner_admin" ON public.groups;
DROP POLICY IF EXISTS "groups_update_owner_admin_or_allowed_member" ON public.groups;

CREATE POLICY "groups_update_owner_admin_or_allowed_member" ON public.groups
  FOR UPDATE
  USING (
    public.get_user_role(id) IN ('owner', 'admin')
    OR (
      public.get_user_role(id) = 'member'
      AND allow_member_change_settings = true
    )
  )
  WITH CHECK (
    public.get_user_role(id) IN ('owner', 'admin')
    OR public.is_group_member(id)
  );

-- ---------------------------------------------------------------------------
-- participants UPDATE: also allow updating your own linked profile row
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "participants_update" ON public.participants;

CREATE POLICY "participants_update" ON public.participants
  FOR UPDATE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_change_settings FROM public.groups g WHERE g.id = group_id) = true
    )
    OR user_id = (SELECT auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Delete cloud data RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_delete_my_data_preview()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  RETURN json_build_object(
    'groups_where_owner', (
      SELECT count(*)::int
      FROM public.group_members
      WHERE user_id = v_uid AND role = 'owner'
    ),
    'group_memberships', (
      SELECT count(*)::int
      FROM public.group_members
      WHERE user_id = v_uid
    ),
    'device_tokens_count', (
      SELECT count(*)::int
      FROM public.device_tokens
      WHERE user_id = v_uid
    ),
    'invite_usages_count', (
      SELECT count(*)::int
      FROM public.invite_usages
      WHERE user_id = v_uid
    ),
    'sole_member_group_count', (
      SELECT count(*)::int
      FROM public.group_members gm
      WHERE gm.user_id = v_uid
        AND NOT EXISTS (
          SELECT 1
          FROM public.group_members gm2
          WHERE gm2.group_id = gm.group_id
            AND gm2.user_id <> v_uid
        )
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_my_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_group_id uuid;
  v_member_count int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  FOR v_group_id IN
    SELECT gm.group_id
    FROM public.group_members gm
    WHERE gm.user_id = v_uid
  LOOP
    SELECT count(*)::int INTO v_member_count
    FROM public.group_members
    WHERE group_id = v_group_id;

    IF v_member_count <= 1 THEN
      -- Sole member: remove the group (cascades members/expenses/etc.).
      DELETE FROM public.groups WHERE id = v_group_id;
    ELSE
      PERFORM public.leave_group(v_group_id);
    END IF;
  END LOOP;

  DELETE FROM public.device_tokens WHERE user_id = v_uid;
  DELETE FROM public.invite_usages WHERE user_id = v_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_delete_my_data_preview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_my_data() TO authenticated;
