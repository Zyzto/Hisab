-- Migration: delete_my_data RPCs and leave_group updates
-- - leave_group: clear treasurer when leaving member is treasurer; delete group when sole member
-- - get_delete_my_data_preview: return counts for delete-cloud-data UI
-- - delete_my_data: leave all groups, delete device_tokens and invite_usages for current user

-- leave_group: clear treasurer when leaving member is treasurer; delete group when sole member
CREATE OR REPLACE FUNCTION public.leave_group(p_group_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_member RECORD;
  v_oldest_member RECORD;
BEGIN
  v_user_id := auth.uid();

  SELECT * INTO v_member FROM public.group_members
  WHERE group_id = p_group_id AND user_id = v_user_id;

  IF v_member IS NULL THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;

  IF v_member.role = 'owner' THEN
    SELECT * INTO v_oldest_member FROM public.group_members
    WHERE group_id = p_group_id AND user_id != v_user_id
    ORDER BY joined_at ASC
    LIMIT 1;

    IF v_oldest_member IS NOT NULL THEN
      UPDATE public.group_members SET role = 'owner' WHERE id = v_oldest_member.id;
      UPDATE public.groups SET owner_id = v_oldest_member.user_id WHERE id = p_group_id;
    ELSE
      UPDATE public.groups SET owner_id = NULL WHERE id = p_group_id;
    END IF;
  END IF;

  -- Clear treasurer if the leaving member's participant is the treasurer
  UPDATE public.groups
  SET treasurer_participant_id = NULL
  WHERE id = p_group_id AND treasurer_participant_id = v_member.participant_id;

  IF v_member.participant_id IS NOT NULL THEN
    UPDATE public.participants
    SET left_at = now(), updated_at = now()
    WHERE id = v_member.participant_id AND group_id = p_group_id;
  END IF;

  DELETE FROM public.group_members WHERE id = v_member.id;

  -- If no members left, delete the group (CASCADE removes participants, expenses, tags, invites)
  IF NOT EXISTS (SELECT 1 FROM public.group_members WHERE group_id = p_group_id) THEN
    DELETE FROM public.groups WHERE id = p_group_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- get_delete_my_data_preview: return counts for current user (for Delete cloud data UI)
CREATE OR REPLACE FUNCTION public.get_delete_my_data_preview()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_groups_where_owner BIGINT;
  v_group_memberships BIGINT;
  v_device_tokens_count BIGINT;
  v_invite_usages_count BIGINT;
  v_sole_member_group_count BIGINT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'groups_where_owner', 0,
      'group_memberships', 0,
      'device_tokens_count', 0,
      'invite_usages_count', 0,
      'sole_member_group_count', 0
    );
  END IF;

  SELECT COUNT(*) INTO v_groups_where_owner
  FROM public.groups g
  WHERE g.owner_id = v_user_id;

  SELECT COUNT(*) INTO v_group_memberships
  FROM public.group_members
  WHERE user_id = v_user_id;

  SELECT COUNT(*) INTO v_device_tokens_count
  FROM public.device_tokens
  WHERE user_id = v_user_id;

  SELECT COUNT(*) INTO v_invite_usages_count
  FROM public.invite_usages
  WHERE user_id = v_user_id;

  -- Groups where this user is the only member (will be deleted when they leave)
  SELECT COUNT(*) INTO v_sole_member_group_count
  FROM public.group_members gm
  WHERE gm.user_id = v_user_id
    AND NOT EXISTS (
      SELECT 1 FROM public.group_members gm2
      WHERE gm2.group_id = gm.group_id AND gm2.user_id != v_user_id
    );

  RETURN jsonb_build_object(
    'groups_where_owner', v_groups_where_owner,
    'group_memberships', v_group_memberships,
    'device_tokens_count', v_device_tokens_count,
    'invite_usages_count', v_invite_usages_count,
    'sole_member_group_count', v_sole_member_group_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- delete_my_data: leave all groups, then delete device_tokens and invite_usages for current user
CREATE OR REPLACE FUNCTION public.delete_my_data()
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_group_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  FOR v_group_id IN
    SELECT gm.group_id FROM public.group_members gm WHERE gm.user_id = v_user_id
  LOOP
    PERFORM public.leave_group(v_group_id);
  END LOOP;

  DELETE FROM public.device_tokens WHERE user_id = v_user_id;
  DELETE FROM public.invite_usages WHERE user_id = v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
