-- In-app notification history for profile activity feed (synced via SyncEngine).

CREATE TABLE public.user_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  group_id uuid REFERENCES public.groups (id) ON DELETE SET NULL,
  actor_user_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  action text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  expense_id uuid,
  payload jsonb,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_notifications_user_created
  ON public.user_notifications (user_id, created_at DESC);

CREATE INDEX idx_user_notifications_user_unread
  ON public.user_notifications (user_id)
  WHERE read_at IS NULL;

ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications"
  ON public.user_notifications FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can update own notifications"
  ON public.user_notifications FOR UPDATE
  TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- Inserts are performed by send-notification edge function with service role.

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
    'user_notifications_count', (
      SELECT count(*)::int
      FROM public.user_notifications
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
      DELETE FROM public.groups WHERE id = v_group_id;
    ELSE
      PERFORM public.leave_group(v_group_id);
    END IF;
  END LOOP;

  DELETE FROM public.device_tokens WHERE user_id = v_uid;
  DELETE FROM public.invite_usages WHERE user_id = v_uid;
  DELETE FROM public.user_notifications WHERE user_id = v_uid;
END;
$$;
