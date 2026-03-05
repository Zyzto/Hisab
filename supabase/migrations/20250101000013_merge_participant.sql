-- Migration 13: merge_participant_with_member RPC
-- Based on docs/SUPABASE_SETUP.md Migration 13

CREATE OR REPLACE FUNCTION public.merge_participant_with_member(
  p_group_id UUID,
  p_participant_id UUID,
  p_member_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_caller_role TEXT;
  v_member_user_id UUID;
  v_display_name TEXT;
  v_avatar_id TEXT;
  v_old_participant_id UUID;
BEGIN
  SELECT role INTO v_caller_role FROM public.group_members
  WHERE group_id = p_group_id AND user_id = auth.uid();
  IF v_caller_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can merge participant with member';
  END IF;

  SELECT user_id, participant_id INTO v_member_user_id, v_old_participant_id
  FROM public.group_members
  WHERE id = p_member_id AND group_id = p_group_id;
  IF v_member_user_id IS NULL THEN
    RAISE EXCEPTION 'Member not found in this group';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.participants WHERE id = p_participant_id AND group_id = p_group_id) THEN
    RAISE EXCEPTION 'Participant not found in this group';
  END IF;

  UPDATE public.group_members SET participant_id = p_participant_id
  WHERE id = p_member_id AND group_id = p_group_id;

  SELECT COALESCE(
    NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(u.raw_user_meta_data->>'name'), ''),
    u.email
  ) INTO v_display_name FROM auth.users u WHERE u.id = v_member_user_id;
  SELECT u.raw_user_meta_data->>'avatar_id' INTO v_avatar_id FROM auth.users u WHERE u.id = v_member_user_id;

  UPDATE public.participants
  SET
    name = COALESCE(NULLIF(TRIM(v_display_name), ''), name),
    user_id = v_member_user_id,
    avatar_id = COALESCE(v_avatar_id, avatar_id),
    updated_at = now()
  WHERE id = p_participant_id AND group_id = p_group_id;

  IF v_old_participant_id IS NOT NULL AND v_old_participant_id != p_participant_id THEN
    DELETE FROM public.participants
    WHERE id = v_old_participant_id AND group_id = p_group_id
      AND NOT EXISTS (SELECT 1 FROM public.expenses WHERE payer_participant_id = v_old_participant_id);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
