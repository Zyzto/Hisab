-- Prevent duplicate active participants for the same auth user in a group.
-- Root cause of "same person twice" in People: participants had no uniqueness on
-- (group_id, user_id), so invite accept / merge / races could create a second row
-- while group_members UNIQUE(group_id, user_id) still held.

-- 0) Remap expense/group refs from duplicate rows onto the keeper (member-linked),
--    merging split share amounts so total cents are preserved. Without this,
--    marking the duplicate as left can orphan payers/splits.
DO $$
DECLARE
  r RECORD;
  v_keep uuid;
  v_leave uuid;
BEGIN
  FOR r IN
    WITH ranked AS (
      SELECT
        p.id,
        p.group_id,
        p.user_id,
        ROW_NUMBER() OVER (
          PARTITION BY p.group_id, p.user_id
          ORDER BY
            CASE
              WHEN EXISTS (
                SELECT 1
                FROM public.group_members gm
                WHERE gm.group_id = p.group_id
                  AND gm.user_id = p.user_id
                  AND gm.participant_id = p.id
              ) THEN 0
              ELSE 1
            END,
            p.created_at ASC NULLS LAST,
            p.id ASC
        ) AS rn
      FROM public.participants p
      WHERE p.user_id IS NOT NULL
        AND p.left_at IS NULL
    )
    SELECT a.id AS keep_id, b.id AS leave_id
    FROM ranked a
    JOIN ranked b
      ON a.group_id = b.group_id
     AND a.user_id = b.user_id
     AND a.rn = 1
     AND b.rn > 1
  LOOP
    v_keep := r.keep_id;
    v_leave := r.leave_id;

    UPDATE public.expenses
    SET payer_participant_id = v_keep
    WHERE payer_participant_id = v_leave;

    UPDATE public.expenses
    SET to_participant_id = v_keep
    WHERE to_participant_id = v_leave;

    UPDATE public.groups
    SET treasurer_participant_id = v_keep
    WHERE treasurer_participant_id = v_leave;

    UPDATE public.group_members
    SET participant_id = v_keep
    WHERE participant_id = v_leave;

    UPDATE public.expenses e
    SET split_shares_json = merged.j,
        updated_at = now()
    FROM (
      SELECT e2.id,
        (
          SELECT jsonb_object_agg(k, to_jsonb(v))::text
          FROM (
            SELECT
              CASE WHEN kv.key = v_leave::text THEN v_keep::text ELSE kv.key END AS k,
              SUM((kv.value)::bigint) AS v
            FROM jsonb_each_text(e2.split_shares_json::jsonb) AS kv(key, value)
            GROUP BY 1
          ) s
        ) AS j
      FROM public.expenses e2
      WHERE e2.split_shares_json IS NOT NULL
        AND e2.split_shares_json LIKE '%' || v_leave::text || '%'
    ) merged
    WHERE e.id = merged.id;
  END LOOP;
END $$;

-- 1) Cleanup: keep one active linked participant per (group_id, user_id).
WITH ranked AS (
  SELECT
    p.id,
    ROW_NUMBER() OVER (
      PARTITION BY p.group_id, p.user_id
      ORDER BY
        CASE
          WHEN EXISTS (
            SELECT 1
            FROM public.group_members gm
            WHERE gm.group_id = p.group_id
              AND gm.user_id = p.user_id
              AND gm.participant_id = p.id
          ) THEN 0
          ELSE 1
        END,
        p.created_at ASC NULLS LAST,
        p.id ASC
    ) AS rn
  FROM public.participants p
  WHERE p.user_id IS NOT NULL
    AND p.left_at IS NULL
)
UPDATE public.participants p
SET left_at = now(),
    updated_at = now()
FROM ranked r
WHERE p.id = r.id
  AND r.rn > 1;

-- 2) Enforce at most one active participant per auth user per group.
CREATE UNIQUE INDEX IF NOT EXISTS idx_participants_active_user_per_group
  ON public.participants (group_id, user_id)
  WHERE user_id IS NOT NULL AND left_at IS NULL;

-- 3) Hardened accept_invite:
--    - reuse any existing row for this user (active orphan or left)
--    - claim explicit p_participant_id when unlinked
--    - claim unique unlinked placeholder by normalized name
--    - insert only as last resort; unique_violation falls back to reuse
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
  v_resolved_participant_id UUID;
  v_claimable_id UUID;
  v_display_name TEXT;
  v_avatar_id TEXT;
  v_email TEXT;
  v_name_for_insert TEXT;
  v_candidate TEXT;
  v_match_count INT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_invite FROM public.group_invites
  WHERE group_invites.token = p_token
    AND (expires_at IS NULL OR expires_at > now());

  IF v_invite IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired invite';
  END IF;

  IF (v_invite.is_active IS NOT NULL AND NOT v_invite.is_active) THEN
    RAISE EXCEPTION 'Invite is not active';
  END IF;

  IF COALESCE(v_invite.access_mode, 'standard') = 'readonly_only' THEN
    RAISE EXCEPTION 'Invite is read-only';
  END IF;

  v_use_count := COALESCE(v_invite.use_count, 0);
  v_max_uses := v_invite.max_uses;
  IF v_max_uses IS NOT NULL AND v_use_count >= v_max_uses THEN
    RAISE EXCEPTION 'Invite has reached max uses';
  END IF;

  v_group_id := v_invite.group_id;

  IF EXISTS (
    SELECT 1
    FROM public.group_members
    WHERE group_id = v_group_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Already a member of this group';
  END IF;

  SELECT
    COALESCE(
      NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), ''),
      NULLIF(TRIM(u.raw_user_meta_data->>'name'), ''),
      u.email
    ),
    u.raw_user_meta_data->>'avatar_id',
    u.email
  INTO v_display_name, v_avatar_id, v_email
  FROM auth.users u
  WHERE u.id = v_user_id;

  v_name_for_insert := COALESCE(
    NULLIF(TRIM(p_new_participant_name), ''),
    NULLIF(TRIM(v_display_name), ''),
    NULLIF(TRIM(v_email), '')
  );

  -- Prefer existing participant for this auth user (active orphan first, then left).
  SELECT id INTO v_resolved_participant_id
  FROM public.participants
  WHERE group_id = v_group_id
    AND user_id = v_user_id
  ORDER BY
    CASE WHEN left_at IS NULL THEN 0 ELSE 1 END,
    created_at ASC NULLS LAST,
    id ASC
  LIMIT 1;

  IF v_resolved_participant_id IS NOT NULL THEN
    UPDATE public.participants
    SET left_at = NULL,
        name = COALESCE(NULLIF(TRIM(v_display_name), ''), name),
        avatar_id = COALESCE(v_avatar_id, avatar_id),
        updated_at = now()
    WHERE id = v_resolved_participant_id
      AND group_id = v_group_id;
  ELSE
    -- Explicit claim of an unlinked placeholder.
    IF p_participant_id IS NOT NULL THEN
      SELECT id INTO v_claimable_id
      FROM public.participants
      WHERE id = p_participant_id
        AND group_id = v_group_id
        AND user_id IS NULL
        AND left_at IS NULL
        AND NOT EXISTS (
          SELECT 1
          FROM public.group_members gm
          WHERE gm.group_id = v_group_id
            AND gm.participant_id = p_participant_id
        );
    END IF;

    -- Auto-claim unique unlinked placeholder by provided name, profile name,
    -- email, or email local-part (covers "Alice" placeholder + email join).
    IF v_claimable_id IS NULL THEN
      FOREACH v_candidate IN ARRAY ARRAY[
        NULLIF(TRIM(p_new_participant_name), ''),
        NULLIF(TRIM(v_display_name), ''),
        -- First token of profile name ("Alice Wonder" → "Alice")
        CASE
          WHEN v_display_name IS NOT NULL
            AND position('@' IN v_display_name) = 0
            AND position(' ' IN trim(v_display_name)) > 0
          THEN NULLIF(TRIM(split_part(trim(v_display_name), ' ', 1)), '')
          ELSE NULL
        END,
        NULLIF(TRIM(v_email), ''),
        NULLIF(
          TRIM(split_part(COALESCE(v_email, ''), '@', 1)),
          ''
        )
      ]
      LOOP
        IF v_candidate IS NULL OR char_length(trim(v_candidate)) < 2 THEN
          CONTINUE;
        END IF;
        -- Single scan: only claim when exactly one unlinked name match exists.
        SELECT (array_agg(p.id ORDER BY p.id))[1], COUNT(*)
          INTO v_claimable_id, v_match_count
        FROM public.participants p
        WHERE p.group_id = v_group_id
          AND p.user_id IS NULL
          AND p.left_at IS NULL
          AND lower(trim(p.name)) = lower(trim(v_candidate))
          AND NOT EXISTS (
            SELECT 1
            FROM public.group_members gm
            WHERE gm.group_id = v_group_id
              AND gm.participant_id = p.id
          );
        IF v_match_count = 1 THEN
          EXIT;
        END IF;
        v_claimable_id := NULL;
      END LOOP;
    END IF;

    -- Claim must stay race-safe: only succeed if still unlinked.
    IF v_claimable_id IS NOT NULL THEN
      UPDATE public.participants
      SET user_id = v_user_id,
          left_at = NULL,
          name = COALESCE(NULLIF(TRIM(v_display_name), ''), name),
          avatar_id = COALESCE(v_avatar_id, avatar_id),
          updated_at = now()
      WHERE id = v_claimable_id
        AND group_id = v_group_id
        AND user_id IS NULL
        AND left_at IS NULL
      RETURNING id INTO v_resolved_participant_id;
    END IF;

    IF v_resolved_participant_id IS NULL AND v_name_for_insert IS NOT NULL THEN
      BEGIN
        INSERT INTO public.participants (group_id, name, sort_order, user_id)
        VALUES (
          v_group_id,
          v_name_for_insert,
          (
            SELECT COALESCE(MAX(sort_order), 0) + 1
            FROM public.participants
            WHERE group_id = v_group_id
          ),
          v_user_id
        )
        RETURNING id INTO v_new_participant_id;
        v_resolved_participant_id := v_new_participant_id;
      EXCEPTION WHEN unique_violation THEN
        SELECT id INTO v_resolved_participant_id
        FROM public.participants
        WHERE group_id = v_group_id
          AND user_id = v_user_id
          AND left_at IS NULL
        ORDER BY created_at ASC NULLS LAST, id ASC
        LIMIT 1;
        IF v_resolved_participant_id IS NULL THEN
          RAISE;
        END IF;
      END;
    END IF;
  END IF;

  BEGIN
    INSERT INTO public.group_members (group_id, user_id, role, participant_id)
    VALUES (v_group_id, v_user_id, v_invite.role, v_resolved_participant_id);
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Already a member of this group';
  END;

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

CREATE OR REPLACE FUNCTION public.accept_invite(p_token TEXT)
RETURNS UUID AS $$
BEGIN
  RETURN public.accept_invite(p_token, NULL, NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- 4) Merge must not leave two active rows with the same user_id.
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
  v_old_in_use BOOLEAN;
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

  IF NOT EXISTS (
    SELECT 1
    FROM public.participants
    WHERE id = p_participant_id AND group_id = p_group_id
  ) THEN
    RAISE EXCEPTION 'Participant not found in this group';
  END IF;

  -- Target must be claimable (unlinked or already this member).
  IF EXISTS (
    SELECT 1
    FROM public.participants
    WHERE id = p_participant_id
      AND group_id = p_group_id
      AND user_id IS NOT NULL
      AND user_id <> v_member_user_id
  ) THEN
    RAISE EXCEPTION 'Participant is already linked to another user';
  END IF;

  UPDATE public.group_members
  SET participant_id = p_participant_id
  WHERE id = p_member_id AND group_id = p_group_id;

  SELECT COALESCE(
    NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(u.raw_user_meta_data->>'name'), ''),
    u.email
  ) INTO v_display_name FROM auth.users u WHERE u.id = v_member_user_id;
  SELECT u.raw_user_meta_data->>'avatar_id'
    INTO v_avatar_id
    FROM auth.users u
    WHERE u.id = v_member_user_id;

  -- Unlink/archive the old auto-created participant first so the unique index allows the claim.
  IF v_old_participant_id IS NOT NULL AND v_old_participant_id != p_participant_id THEN
    UPDATE public.participants
    SET user_id = NULL,
        left_at = COALESCE(left_at, now()),
        updated_at = now()
    WHERE id = v_old_participant_id
      AND group_id = p_group_id;
  END IF;

  UPDATE public.participants
  SET
    name = COALESCE(NULLIF(TRIM(v_display_name), ''), name),
    user_id = v_member_user_id,
    left_at = NULL,
    avatar_id = COALESCE(v_avatar_id, avatar_id),
    updated_at = now()
  WHERE id = p_participant_id
    AND group_id = p_group_id
    AND (user_id IS NULL OR user_id = v_member_user_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Participant is already linked to another user';
  END IF;

  IF v_old_participant_id IS NOT NULL AND v_old_participant_id != p_participant_id THEN
    SELECT EXISTS (
      SELECT 1 FROM public.expenses
      WHERE payer_participant_id = v_old_participant_id
         OR to_participant_id = v_old_participant_id
         OR (
           split_shares_json IS NOT NULL
           AND split_shares_json LIKE '%' || v_old_participant_id::text || '%'
         )
    ) OR EXISTS (
      SELECT 1 FROM public.groups
      WHERE id = p_group_id
        AND treasurer_participant_id = v_old_participant_id
    )
    INTO v_old_in_use;

    IF NOT v_old_in_use THEN
      DELETE FROM public.participants
      WHERE id = v_old_participant_id AND group_id = p_group_id;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- 5) Leave/kick: mark every active participant row for that user as left.
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

  UPDATE public.participants
  SET left_at = now(), updated_at = now()
  WHERE group_id = p_group_id
    AND left_at IS NULL
    AND (
      user_id = v_user_id
      OR (v_member.participant_id IS NOT NULL AND id = v_member.participant_id)
    );

  DELETE FROM public.group_members WHERE id = v_member.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

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

  UPDATE public.participants
  SET left_at = now(), updated_at = now()
  WHERE group_id = p_group_id
    AND left_at IS NULL
    AND (
      user_id = v_target.user_id
      OR (v_target.participant_id IS NOT NULL AND id = v_target.participant_id)
    );

  DELETE FROM public.group_members WHERE id = p_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
