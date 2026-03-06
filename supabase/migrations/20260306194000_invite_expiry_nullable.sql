-- Support never-expiring invites by allowing expires_at to be NULL.

ALTER TABLE public.group_invites
  ALTER COLUMN expires_at DROP NOT NULL;
