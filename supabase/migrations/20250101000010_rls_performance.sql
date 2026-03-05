-- Migration 10: RLS performance – auth initplan and merged policies
-- Based on docs/SUPABASE_SETUP.md Migration 10

DROP POLICY IF EXISTS "groups_select" ON public.groups;
DROP POLICY IF EXISTS "groups_select_members" ON public.groups;
DROP POLICY IF EXISTS "groups_select_owner" ON public.groups;
CREATE POLICY "groups_select" ON public.groups
  FOR SELECT USING (
    public.is_group_member(id)
    OR (SELECT auth.uid()) = owner_id
  );

DROP POLICY IF EXISTS "groups_insert_authenticated" ON public.groups;
CREATE POLICY "groups_insert_authenticated" ON public.groups
  FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND owner_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "group_members_insert" ON public.group_members;
CREATE POLICY "group_members_insert" ON public.group_members
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      user_id = (SELECT auth.uid())
      AND role = 'owner'
      AND (SELECT g.owner_id FROM public.groups g WHERE g.id = group_id) = (SELECT auth.uid())
    )
  );
DROP POLICY IF EXISTS "group_members_delete" ON public.group_members;
CREATE POLICY "group_members_delete" ON public.group_members
  FOR DELETE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR user_id = (SELECT auth.uid())
  );

DROP POLICY IF EXISTS "participants_insert" ON public.participants;
CREATE POLICY "participants_insert" ON public.participants
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_add_participant FROM public.groups g WHERE g.id = group_id) = true
    )
    OR (SELECT g.owner_id FROM public.groups g WHERE g.id = group_id) = (SELECT auth.uid())
  );

DROP POLICY IF EXISTS "Group members can view invite usages" ON public.invite_usages;
DROP POLICY IF EXISTS "invite_usages_select_members" ON public.invite_usages;
CREATE POLICY "invite_usages_select_members" ON public.invite_usages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.group_invites gi
      JOIN public.group_members gm ON gm.group_id = gi.group_id AND gm.user_id = (SELECT auth.uid())
      WHERE gi.id = invite_usages.invite_id
    )
  );
DROP POLICY IF EXISTS "invite_usages_insert_own" ON public.invite_usages;
CREATE POLICY "invite_usages_insert_own" ON public.invite_usages
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can view own tokens" ON public.device_tokens;
DROP POLICY IF EXISTS "Users can insert own tokens" ON public.device_tokens;
DROP POLICY IF EXISTS "Users can update own tokens" ON public.device_tokens;
DROP POLICY IF EXISTS "Users can delete own tokens" ON public.device_tokens;
CREATE POLICY "Users can view own tokens" ON public.device_tokens
  FOR SELECT USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can insert own tokens" ON public.device_tokens
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can update own tokens" ON public.device_tokens
  FOR UPDATE USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can delete own tokens" ON public.device_tokens
  FOR DELETE USING ((SELECT auth.uid()) = user_id);
