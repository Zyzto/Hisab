-- Migration 14: Participants left/archived (left_at) and re-join reuse
-- Adds left_at to participants; leave_group/kick_member set it; accept_invite reuses former participant; archive_participant RPC.
-- Run after Migration 13 (merge_participant_with_member).

-- Add left_at to participants (nullable; when set, treat as left/archived)
ALTER TABLE public.participants
  ADD COLUMN IF NOT EXISTS left_at TIMESTAMPTZ;

-- Backfill: mark existing "orphan" participants (have user_id but no current group_member) as left
UPDATE public.participants p
SET left_at = COALESCE(p.updated_at, now()), updated_at = now()
WHERE p.user_id IS NOT NULL
  AND p.left_at IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.group_members gm
    WHERE gm.group_id = p.group_id AND gm.participant_id = p.id
  );

-- leave_group: mark participant as left, then delete membership
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

  IF v_member.participant_id IS NOT NULL THEN
    UPDATE public.participants
    SET left_at = now(), updated_at = now()
    WHERE id = v_member.participant_id AND group_id = p_group_id;
  END IF;

  DELETE FROM public.group_members WHERE id = v_member.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- kick_member: mark participant as left, then delete membership
CREATE OR REPLACE FUNCTION public.kick_member(
  p_group_id UUID,
  p_member_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_kicker_role TEXT;
  v_target RECORD;
BEGIN
  v_user_id := auth.uid();

  SELECT role INTO v_kicker_role FROM public.group_members
  WHERE group_id = p_group_id AND user_id = v_user_id;

  IF v_kicker_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can kick members';
  END IF;

  SELECT * INTO v_target FROM public.group_members
  WHERE id = p_member_id AND group_id = p_group_id;

  IF v_target IS NULL THEN
    RAISE EXCEPTION 'Member not found in this group';
  END IF;

  IF v_target.role = 'owner' THEN
    RAISE EXCEPTION 'Cannot kick the owner';
  END IF;

  IF v_target.participant_id IS NOT NULL THEN
    UPDATE public.participants
    SET left_at = now(), updated_at = now()
    WHERE id = v_target.participant_id AND group_id = p_group_id;
  END IF;

  DELETE FROM public.group_members WHERE id = p_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- accept_invite: reuse participant with same user_id and left_at IS NOT NULL when present
CREATE OR REPLACE FUNCTION public.accept_invite(
  p_token TEXT,
  p_participant_id UUID DEFAULT NULL,
  p_new_participant_name TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_invite RECORD;
  v_user_id UUID;
  v_group_id UUID;
  v_new_participant_id UUID;
  v_use_count INT;
  v_max_uses INT;
  v_reuse_participant_id UUID;
  v_display_name TEXT;
  v_avatar_id TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_invite FROM public.group_invites
  WHERE group_invites.token = p_token AND expires_at > now();

  IF v_invite IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired invite';
  END IF;

  IF (v_invite.is_active IS NOT NULL AND NOT v_invite.is_active) THEN
    RAISE EXCEPTION 'Invite is not active';
  END IF;

  v_use_count := COALESCE(v_invite.use_count, 0);
  v_max_uses := v_invite.max_uses;
  IF v_max_uses IS NOT NULL AND v_use_count >= v_max_uses THEN
    RAISE EXCEPTION 'Invite has reached max uses';
  END IF;

  v_group_id := v_invite.group_id;

  IF EXISTS (SELECT 1 FROM public.group_members WHERE group_id = v_group_id AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'Already a member of this group';
  END IF;

  -- Re-use a former participant (same user, left) if present
  SELECT id INTO v_reuse_participant_id FROM public.participants
  WHERE group_id = v_group_id AND user_id = v_user_id AND left_at IS NOT NULL
  LIMIT 1;

  IF v_reuse_participant_id IS NOT NULL THEN
    SELECT COALESCE(
      NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), ''),
      NULLIF(TRIM(u.raw_user_meta_data->>'name'), ''),
      u.email
    ) INTO v_display_name FROM auth.users u WHERE u.id = v_user_id;
    SELECT u.raw_user_meta_data->>'avatar_id' INTO v_avatar_id FROM auth.users u WHERE u.id = v_user_id;
    UPDATE public.participants
    SET left_at = NULL,
        name = COALESCE(NULLIF(TRIM(v_display_name), ''), name),
        avatar_id = COALESCE(v_avatar_id, avatar_id),
        updated_at = now()
    WHERE id = v_reuse_participant_id AND group_id = v_group_id;
    p_participant_id := v_reuse_participant_id;
  ELSIF p_new_participant_name IS NOT NULL AND p_new_participant_name != '' THEN
    INSERT INTO public.participants (group_id, name, sort_order, user_id)
    VALUES (v_group_id, p_new_participant_name,
      (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM public.participants WHERE group_id = v_group_id),
      v_user_id)
    RETURNING id INTO v_new_participant_id;
    p_participant_id := v_new_participant_id;
  END IF;

  INSERT INTO public.group_members (group_id, user_id, role, participant_id)
  VALUES (v_group_id, v_user_id, v_invite.role, p_participant_id);

  INSERT INTO public.invite_usages (invite_id, user_id)
  VALUES (v_invite.id, v_user_id);

  UPDATE public.group_invites
  SET use_count = v_use_count + 1
  WHERE id = v_invite.id;

  IF v_max_uses IS NOT NULL AND (v_use_count + 1) >= v_max_uses THEN
    DELETE FROM public.group_invites WHERE id = v_invite.id;
  END IF;

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- archive_participant: owner/admin sets left_at so the person can be hidden from the list (expense history kept)
CREATE OR REPLACE FUNCTION public.archive_participant(
  p_group_id UUID,
  p_participant_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT role INTO v_role FROM public.group_members
  WHERE group_id = p_group_id AND user_id = auth.uid();
  IF v_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can archive participants';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.participants WHERE id = p_participant_id AND group_id = p_group_id) THEN
    RAISE EXCEPTION 'Participant not found in this group';
  END IF;
  UPDATE public.participants
  SET left_at = now(), updated_at = now()
  WHERE id = p_participant_id AND group_id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
