# Supabase Backend Setup Guide

This guide walks you through setting up the Supabase backend for Hisab from scratch. Follow these steps if you are self-hosting or contributing to the project and need your own Supabase instance.

> **Offline mode**: Hisab works fully offline without any Supabase configuration. Online features (sync, auth, invites, telemetry) are only available when Supabase is configured.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Create a Supabase Project](#2-create-a-supabase-project)
3. [Apply Database Migrations](#3-apply-database-migrations)
   - [Migration 1: Tables, Indexes, and Triggers](#migration-1-tables-indexes-and-triggers)
   - [Migration 2: Row Level Security (RLS) Policies](#migration-2-row-level-security-rls-policies)
   - [Migration 3: RPC Functions](#migration-3-rpc-functions)
   - [Migration 4: Security Hardening](#migration-4-security-hardening)
   - [Migration 5: Device Tokens (Push Notifications)](#migration-5-device-tokens-push-notifications)
   - [Migration 6: Notification Triggers](#migration-6-notification-triggers)
   - [Migration 6b: device_tokens locale (language-aware notifications)](#migration-6b-device_tokens-locale-language-aware-notifications)
   - [Migration 7: Schema Additions (drift fix)](#migration-7-schema-additions-drift-fix)
   - [Migration 8: RPC updates (invites)](#migration-8-rpc-updates-invites)
   - [Migration 9: Security hardening (search_path, revoke/toggle RPCs)](#migration-9-security-hardening-search_path-revoketoggle-rpcs)
   - [Migration 10: RLS performance (auth initplan and merged groups SELECT)](#migration-10-rls-performance-auth-initplan-and-merged-groups-select)
   - [Migration 11: Indexes (composite, partial, and FK)](#migration-11-indexes-composite-partial-and-fk)
   - [Migration 12: Groups archive (archived_at)](#migration-12-groups-archive-archived_at)
   - [Migration 13: merge_participant_with_member (merge manual participant with user)](#migration-13-merge_participant_with_member-merge-manual-participant-with-user)
   - [Migration 14: Participants left/archived (left_at) and re-join reuse](#migration-14-participants-leftarchived-left_at-and-re-join-reuse)
   - [Migration 15: Receipt images Storage bucket](#migration-15-receipt-images-storage-bucket)
4. [Configure Authentication](#4-configure-authentication)
5. [Deploy Edge Functions](#5-deploy-edge-functions)
   - [Push notifications: end-to-end flow and verification](#push-notifications-end-to-end-flow-and-verification)
6. [Configure the Flutter App](#6-configure-the-flutter-app)
7. [Verify the Setup](#7-verify-the-setup)
8. [Architecture Overview](#8-architecture-overview)
9. [Troubleshooting](#9-troubleshooting)
10. [Testing](#10-testing)

---

## 1. Prerequisites

- A [Supabase](https://supabase.com/) account (free tier works)
- [Supabase CLI](https://supabase.com/docs/guides/cli) installed (optional, for Edge Functions)
- Flutter SDK installed
- A Google Cloud project (for Google OAuth, optional)
- A GitHub OAuth app (for GitHub OAuth, optional)

---

## 2. Create a Supabase Project

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard) and create a new project.
2. Choose a name (e.g., "Hisab"), region, and set a database password.
3. Once created, note the following from **Settings > API**:
   - **Project URL** (e.g., `https://xxxxxxxxxxxxx.supabase.co`)
   - **anon (public) key** (starts with `eyJ...`)
4. These values are used in `--dart-define` when running the Flutter app.

---

## 3. Apply Database Migrations

Go to the **SQL Editor** in your Supabase dashboard and run each migration in order. You can also use the Supabase CLI or MCP tools.

### Migration 1: Tables, Indexes, and Triggers

This creates the core schema: 7 tables, indexes, and an `updated_at` trigger.

```sql
-- =============================================
-- Hisab Database Schema: Tables, Indexes, Triggers
-- =============================================

-- updated_at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- groups table
CREATE TABLE public.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 200),
  currency_code TEXT NOT NULL CHECK (length(currency_code) = 3),
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  settlement_method TEXT DEFAULT 'greedy',
  treasurer_participant_id UUID,
  settlement_freeze_at TIMESTAMPTZ,
  settlement_snapshot_json TEXT,
  allow_member_add_expense BOOLEAN DEFAULT true NOT NULL,
  allow_member_add_participant BOOLEAN DEFAULT true NOT NULL,
  allow_member_change_settings BOOLEAN DEFAULT true NOT NULL,
  require_participant_assignment BOOLEAN DEFAULT false NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- participants table
CREATE TABLE public.participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100),
  sort_order INT DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Add FK for treasurer_participant_id (after participants exists)
ALTER TABLE public.groups
  ADD CONSTRAINT fk_groups_treasurer_participant
  FOREIGN KEY (treasurer_participant_id) REFERENCES public.participants(id) ON DELETE SET NULL;

-- group_members table
CREATE TABLE public.group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member')),
  participant_id UUID REFERENCES public.participants(id) ON DELETE SET NULL,
  joined_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  UNIQUE(group_id, user_id)
);

-- expenses table
CREATE TABLE public.expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  payer_participant_id UUID NOT NULL REFERENCES public.participants(id) ON DELETE CASCADE,
  amount_cents INT NOT NULL,
  currency_code TEXT NOT NULL CHECK (length(currency_code) = 3),
  title TEXT NOT NULL CHECK (length(title) >= 1 AND length(title) <= 500),
  description TEXT,
  date TIMESTAMPTZ NOT NULL,
  split_type TEXT NOT NULL CHECK (split_type IN ('equal', 'parts', 'amounts')),
  split_shares_json TEXT,
  type TEXT DEFAULT 'expense' NOT NULL CHECK (type IN ('expense', 'income', 'transfer')),
  to_participant_id UUID REFERENCES public.participants(id) ON DELETE SET NULL,
  tag TEXT,
  line_items_json TEXT,
  receipt_image_path TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- expense_tags table
CREATE TABLE public.expense_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  label TEXT NOT NULL CHECK (length(label) >= 1 AND length(label) <= 100),
  icon_name TEXT NOT NULL CHECK (length(icon_name) >= 1 AND length(icon_name) <= 80),
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- group_invites table
CREATE TABLE public.group_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  invitee_email TEXT,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL
);

-- telemetry table (anonymous usage analytics)
CREATE TABLE public.telemetry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event TEXT NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT now(),
  data JSONB
);

-- Indexes
CREATE INDEX idx_group_members_group_id ON public.group_members(group_id);
CREATE INDEX idx_group_members_user_id ON public.group_members(user_id);
CREATE INDEX idx_group_invites_group_id ON public.group_invites(group_id);
CREATE INDEX idx_participants_group_id ON public.participants(group_id);
CREATE INDEX idx_participants_group_id_sort_order ON public.participants(group_id, sort_order);
CREATE INDEX idx_expenses_group_id ON public.expenses(group_id);
CREATE INDEX idx_expenses_group_id_date_desc ON public.expenses(group_id, date DESC);
CREATE INDEX idx_expense_tags_group_id ON public.expense_tags(group_id);

-- Updated-at triggers
CREATE TRIGGER set_groups_updated_at
  BEFORE UPDATE ON public.groups
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_participants_updated_at
  BEFORE UPDATE ON public.participants
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_expenses_updated_at
  BEFORE UPDATE ON public.expenses
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_expense_tags_updated_at
  BEFORE UPDATE ON public.expense_tags
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
```

### Migration 2: Row Level Security (RLS) Policies

This enables RLS on all tables and creates granular access policies based on group membership and roles.

```sql
-- =============================================
-- Helper Functions
-- =============================================

-- Get user's role in a group
CREATE OR REPLACE FUNCTION public.get_user_role(p_group_id UUID)
RETURNS TEXT AS $$
  SELECT role FROM public.group_members
  WHERE group_id = p_group_id AND user_id = auth.uid()
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Check if user is member of group
CREATE OR REPLACE FUNCTION public.is_group_member(p_group_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group_id AND user_id = auth.uid()
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- =============================================
-- Enable RLS on all tables
-- =============================================
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.telemetry ENABLE ROW LEVEL SECURITY;

-- =============================================
-- Groups Policies (single SELECT for performance; (select auth.uid()) for initplan)
-- =============================================
CREATE POLICY "groups_select" ON public.groups
  FOR SELECT USING (
    public.is_group_member(id)
    OR (SELECT auth.uid()) = owner_id
  );

CREATE POLICY "groups_insert_authenticated" ON public.groups
  FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND owner_id = (SELECT auth.uid()));

CREATE POLICY "groups_update_owner_admin" ON public.groups
  FOR UPDATE USING (public.get_user_role(id) IN ('owner', 'admin'));

CREATE POLICY "groups_delete_owner" ON public.groups
  FOR DELETE USING (public.get_user_role(id) = 'owner');

-- =============================================
-- Group Members Policies
-- =============================================
CREATE POLICY "group_members_select" ON public.group_members
  FOR SELECT USING (public.is_group_member(group_id));

CREATE POLICY "group_members_insert" ON public.group_members
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      user_id = (SELECT auth.uid())
      AND role = 'owner'
      AND (SELECT g.owner_id FROM public.groups g WHERE g.id = group_id) = (SELECT auth.uid())
    )
  );

CREATE POLICY "group_members_update" ON public.group_members
  FOR UPDATE USING (public.get_user_role(group_id) IN ('owner', 'admin'));

CREATE POLICY "group_members_delete" ON public.group_members
  FOR DELETE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR user_id = (SELECT auth.uid())
  );

-- =============================================
-- Participants Policies
-- =============================================
CREATE POLICY "participants_select" ON public.participants
  FOR SELECT USING (public.is_group_member(group_id));

CREATE POLICY "participants_insert" ON public.participants
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_add_participant FROM public.groups g WHERE g.id = group_id) = true
    )
    OR (SELECT g.owner_id FROM public.groups g WHERE g.id = group_id) = (SELECT auth.uid())
  );

CREATE POLICY "participants_update" ON public.participants
  FOR UPDATE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_change_settings FROM public.groups g WHERE g.id = group_id) = true
    )
  );

CREATE POLICY "participants_delete" ON public.participants
  FOR DELETE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (
        (SELECT g.allow_member_add_participant FROM public.groups g WHERE g.id = group_id) = true
        OR (SELECT g.allow_member_change_settings FROM public.groups g WHERE g.id = group_id) = true
      )
    )
  );

-- =============================================
-- Expenses Policies
-- =============================================
CREATE POLICY "expenses_select" ON public.expenses
  FOR SELECT USING (public.is_group_member(group_id));

CREATE POLICY "expenses_insert" ON public.expenses
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_add_expense FROM public.groups g WHERE g.id = group_id) = true
    )
  );

CREATE POLICY "expenses_update" ON public.expenses
  FOR UPDATE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_add_expense FROM public.groups g WHERE g.id = group_id) = true
    )
  );

CREATE POLICY "expenses_delete" ON public.expenses
  FOR DELETE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_add_expense FROM public.groups g WHERE g.id = group_id) = true
    )
  );

-- =============================================
-- Expense Tags Policies
-- =============================================
CREATE POLICY "expense_tags_select" ON public.expense_tags
  FOR SELECT USING (public.is_group_member(group_id));

CREATE POLICY "expense_tags_insert" ON public.expense_tags
  FOR INSERT WITH CHECK (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_change_settings FROM public.groups g WHERE g.id = group_id) = true
    )
  );

CREATE POLICY "expense_tags_update" ON public.expense_tags
  FOR UPDATE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_change_settings FROM public.groups g WHERE g.id = group_id) = true
    )
  );

CREATE POLICY "expense_tags_delete" ON public.expense_tags
  FOR DELETE USING (
    public.get_user_role(group_id) IN ('owner', 'admin')
    OR (
      public.get_user_role(group_id) = 'member'
      AND (SELECT g.allow_member_change_settings FROM public.groups g WHERE g.id = group_id) = true
    )
  );

-- =============================================
-- Group Invites Policies
-- =============================================
CREATE POLICY "group_invites_select_members" ON public.group_invites
  FOR SELECT USING (public.is_group_member(group_id));

CREATE POLICY "group_invites_insert" ON public.group_invites
  FOR INSERT WITH CHECK (public.get_user_role(group_id) IN ('owner', 'admin'));

CREATE POLICY "group_invites_delete" ON public.group_invites
  FOR DELETE USING (public.get_user_role(group_id) IN ('owner', 'admin'));

-- =============================================
-- Telemetry Policies (insert-only, any user including anonymous)
-- Intentional: anonymous usage events; WITH CHECK (true) is deliberate.
-- =============================================
CREATE POLICY "telemetry_insert" ON public.telemetry
  FOR INSERT WITH CHECK (true);
```

### Migration 3: RPC Functions

These server-side functions handle complex multi-table operations that need to bypass RLS (they run as `SECURITY DEFINER`).

```sql
-- =============================================
-- RPC Functions for multi-table operations
-- =============================================

-- get_invite_by_token: lookup invite + group info (bypasses RLS for token-based access)
CREATE OR REPLACE FUNCTION public.get_invite_by_token(p_token TEXT)
RETURNS TABLE(
  invite_id UUID,
  group_id UUID,
  token TEXT,
  invitee_email TEXT,
  role TEXT,
  created_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  group_name TEXT,
  group_currency_code TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    gi.id AS invite_id,
    gi.group_id,
    gi.token,
    gi.invitee_email,
    gi.role,
    gi.created_at,
    gi.expires_at,
    g.name AS group_name,
    g.currency_code AS group_currency_code
  FROM public.group_invites gi
  JOIN public.groups g ON g.id = gi.group_id
  WHERE gi.token = p_token
    AND gi.expires_at > now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- accept_invite: validates token, creates membership, optionally creates participant, deletes invite
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

  v_group_id := v_invite.group_id;

  IF EXISTS (SELECT 1 FROM public.group_members WHERE group_id = v_group_id AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'Already a member of this group';
  END IF;

  IF p_new_participant_name IS NOT NULL AND p_new_participant_name != '' THEN
    INSERT INTO public.participants (group_id, name, sort_order)
    VALUES (v_group_id, p_new_participant_name,
      (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM public.participants WHERE group_id = v_group_id))
    RETURNING id INTO v_new_participant_id;
    p_participant_id := v_new_participant_id;
  END IF;

  INSERT INTO public.group_members (group_id, user_id, role, participant_id)
  VALUES (v_group_id, v_user_id, v_invite.role, p_participant_id);

  DELETE FROM public.group_invites WHERE id = v_invite.id;

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- transfer_ownership: swaps owner/admin roles atomically
CREATE OR REPLACE FUNCTION public.transfer_ownership(
  p_group_id UUID,
  p_new_owner_member_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_current_member RECORD;
  v_new_owner_member RECORD;
BEGIN
  v_user_id := auth.uid();

  SELECT * INTO v_current_member FROM public.group_members
  WHERE group_id = p_group_id AND user_id = v_user_id AND role = 'owner';

  IF v_current_member IS NULL THEN
    RAISE EXCEPTION 'Only the owner can transfer ownership';
  END IF;

  SELECT * INTO v_new_owner_member FROM public.group_members
  WHERE id = p_new_owner_member_id AND group_id = p_group_id;

  IF v_new_owner_member IS NULL THEN
    RAISE EXCEPTION 'Member not found in this group';
  END IF;

  UPDATE public.group_members SET role = 'admin' WHERE id = v_current_member.id;
  UPDATE public.group_members SET role = 'owner' WHERE id = v_new_owner_member.id;
  UPDATE public.groups SET owner_id = v_new_owner_member.user_id WHERE id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- leave_group: handles ownership transfer on leave, deletes membership
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

  DELETE FROM public.group_members WHERE id = v_member.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- kick_member: validates role, removes membership
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

  DELETE FROM public.group_members WHERE id = p_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- update_member_role: owner changes a member's role
CREATE OR REPLACE FUNCTION public.update_member_role(
  p_group_id UUID,
  p_member_id UUID,
  p_role TEXT
)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_target RECORD;
BEGIN
  v_user_id := auth.uid();

  IF p_role NOT IN ('admin', 'member') THEN
    RAISE EXCEPTION 'Invalid role. Must be admin or member';
  END IF;

  SELECT role INTO v_user_role FROM public.group_members
  WHERE group_id = p_group_id AND user_id = v_user_id;

  IF v_user_role != 'owner' THEN
    RAISE EXCEPTION 'Only the owner can change roles';
  END IF;

  SELECT * INTO v_target FROM public.group_members
  WHERE id = p_member_id AND group_id = p_group_id;

  IF v_target IS NULL THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  IF v_target.role = 'owner' THEN
    RAISE EXCEPTION 'Cannot change owner role directly. Use transfer_ownership instead';
  END IF;

  UPDATE public.group_members SET role = p_role WHERE id = p_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- assign_participant: owner/admin assigns a participant to a member
CREATE OR REPLACE FUNCTION public.assign_participant(
  p_group_id UUID,
  p_member_id UUID,
  p_participant_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_participant RECORD;
BEGIN
  v_user_id := auth.uid();

  SELECT role INTO v_user_role FROM public.group_members
  WHERE group_id = p_group_id AND user_id = v_user_id;

  IF v_user_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can assign participants';
  END IF;

  SELECT * INTO v_participant FROM public.participants
  WHERE id = p_participant_id AND group_id = p_group_id;

  IF v_participant IS NULL THEN
    RAISE EXCEPTION 'Participant not found in this group';
  END IF;

  UPDATE public.group_members SET participant_id = p_participant_id
  WHERE id = p_member_id AND group_id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- create_invite: generates token, creates invite
CREATE OR REPLACE FUNCTION public.create_invite(
  p_group_id UUID,
  p_invitee_email TEXT DEFAULT NULL,
  p_role TEXT DEFAULT 'member'
)
RETURNS TABLE(id UUID, token TEXT) AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_token TEXT;
  v_invite_id UUID;
BEGIN
  v_user_id := auth.uid();

  SELECT gm.role INTO v_user_role FROM public.group_members gm
  WHERE gm.group_id = p_group_id AND gm.user_id = v_user_id;

  IF v_user_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can create invites';
  END IF;

  v_token := pg_catalog.encode(extensions.gen_random_bytes(18), 'base64');
  v_token := replace(replace(replace(v_token, '+', ''), '/', ''), '=', '');
  v_token := substr(v_token, 1, 24);

  INSERT INTO public.group_invites (group_id, token, invitee_email, role, expires_at)
  VALUES (p_group_id, v_token, p_invitee_email, p_role, now() + interval '7 days')
  RETURNING group_invites.id INTO v_invite_id;

  RETURN QUERY SELECT v_invite_id, v_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Migration 4: Security Hardening

This fixes the `search_path` on all functions to prevent search path manipulation attacks.

```sql
-- Fix search_path on all functions for security

ALTER FUNCTION public.handle_updated_at() SET search_path = '';

ALTER FUNCTION public.get_user_role(UUID) SET search_path = '';
ALTER FUNCTION public.is_group_member(UUID) SET search_path = '';

ALTER FUNCTION public.get_invite_by_token(TEXT) SET search_path = '';
ALTER FUNCTION public.accept_invite(TEXT, UUID, TEXT) SET search_path = '';
ALTER FUNCTION public.transfer_ownership(UUID, UUID) SET search_path = '';
ALTER FUNCTION public.leave_group(UUID) SET search_path = '';
ALTER FUNCTION public.kick_member(UUID, UUID) SET search_path = '';
ALTER FUNCTION public.update_member_role(UUID, UUID, TEXT) SET search_path = '';
ALTER FUNCTION public.assign_participant(UUID, UUID, UUID) SET search_path = '';
ALTER FUNCTION public.create_invite(UUID, TEXT, TEXT) SET search_path = '';
```

### Migration 5: Device Tokens (Push Notifications)

Creates the `public.device_tokens` table for storing FCM push notification tokens per user/device. The table lives in the `public` schema; one row per (user_id, token) is enforced by the unique index.

```sql
-- Device tokens table for FCM push notifications (public schema)
CREATE TABLE public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX idx_device_tokens_unique ON public.device_tokens(user_id, token);
CREATE INDEX idx_device_tokens_user ON public.device_tokens(user_id);

-- Trigger to auto-update updated_at
CREATE TRIGGER set_device_tokens_updated_at
  BEFORE UPDATE ON public.device_tokens
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RLS: users can only manage their own tokens
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own tokens"
  ON public.device_tokens FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own tokens"
  ON public.device_tokens FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tokens"
  ON public.device_tokens FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own tokens"
  ON public.device_tokens FOR DELETE
  USING (auth.uid() = user_id);
```

### Migration 6: Notification Triggers

Enables the `pg_net` extension and creates database triggers that asynchronously call the `send-notification` edge function when expenses are created/updated or members join a group.

**Prerequisites:**
1. Deploy the `send-notification` edge function (see [Section 5](#5-deploy-edge-functions)).
2. Store the service role key in Supabase Vault:
   ```sql
   -- Run this in the SQL Editor (replace with your actual service role key from Dashboard > Settings > API)
   SELECT vault.create_secret('YOUR_SERVICE_ROLE_KEY_HERE', 'service_role_key');
   ```
3. **Before running the migration:** Replace `YOUR_SUPABASE_URL` in the trigger function below with your actual Supabase project URL (e.g. `https://xxxxxxxxxxxxx.supabase.co`). You can copy it from **Settings > API > Project URL** in the dashboard. If you run the migration without replacing it, the trigger will POST to an invalid host and no notifications will be sent.

```sql
-- Enable pg_net extension for async HTTP calls from triggers
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Trigger function: sends a notification payload to the send-notification
-- edge function via pg_net (async, fire-and-forget).
-- IMPORTANT: Replace YOUR_SUPABASE_URL with your actual project URL (Settings > API > Project URL).
CREATE OR REPLACE FUNCTION notify_group_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_group_id UUID;
  v_actor_id UUID;
  v_action TEXT;
  v_expense_title TEXT;
  v_amount_cents INTEGER;
  v_currency_code TEXT;
  v_supabase_url TEXT := 'YOUR_SUPABASE_URL';
  v_service_role_key TEXT;
BEGIN
  -- Get the service role key from vault
  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  -- If no service role key in vault, skip gracefully
  IF v_service_role_key IS NULL THEN
    RAISE LOG 'notify_group_activity: service_role_key not found in vault, skipping';
    RETURN NEW;
  END IF;

  -- Determine action and extract fields based on trigger source
  IF TG_TABLE_NAME = 'expenses' THEN
    v_group_id := NEW.group_id;
    v_actor_id := auth.uid();
    v_expense_title := NEW.title;
    v_amount_cents := NEW.amount_cents;
    v_currency_code := NEW.currency_code;

    IF TG_OP = 'INSERT' THEN
      v_action := 'expense_created';
    ELSIF TG_OP = 'UPDATE' THEN
      v_action := 'expense_updated';
    END IF;

  ELSIF TG_TABLE_NAME = 'group_members' THEN
    v_group_id := NEW.group_id;
    v_actor_id := NEW.user_id;
    v_action := 'member_joined';
  END IF;

  -- Skip if we couldn't determine the action or actor
  IF v_action IS NULL OR v_actor_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Fire-and-forget HTTP POST to the edge function via pg_net
  PERFORM net.http_post(
    url := v_supabase_url || '/functions/v1/send-notification',
    body := jsonb_build_object(
      'group_id', v_group_id,
      'actor_user_id', v_actor_id,
      'action', v_action,
      'expense_title', v_expense_title,
      'amount_cents', v_amount_cents,
      'currency_code', v_currency_code
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    )
  );

  RETURN NEW;
END;
$$;

-- Notify on new or edited expenses
CREATE TRIGGER notify_on_expense_change
  AFTER INSERT OR UPDATE ON expenses
  FOR EACH ROW
  EXECUTE FUNCTION notify_group_activity();

-- Notify when a new member joins a group
CREATE TRIGGER notify_on_member_join
  AFTER INSERT ON group_members
  FOR EACH ROW
  EXECUTE FUNCTION notify_group_activity();
```

### Migration 6b: device_tokens locale (language-aware notifications)

Adds an optional `locale` column to `device_tokens` so the send-notification Edge Function can deliver push notifications in the recipient's app language (e.g. `en`, `ar`). Run after Migration 6. Existing rows keep `locale` null and receive English. The Flutter app sends the current app language when registering or refreshing the FCM token so each device gets notifications in the right language.

```sql
-- device_tokens: optional locale for localized push notification text
ALTER TABLE public.device_tokens
  ADD COLUMN IF NOT EXISTS locale TEXT;
```

### Migration 7: Schema Additions (drift fix)

Run this migration after Migrations 1–6 to add columns and the `invite_usages` table so the schema matches what the app expects. Safe for existing projects (uses `ALTER TABLE` / `CREATE TABLE`); new projects run 1–6 then 7 for a full schema.

```sql
-- =============================================
-- Schema additions: columns and invite_usages
-- =============================================

-- group_invites: optional label, usage limits, creator, active flag
ALTER TABLE public.group_invites
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS label TEXT,
  ADD COLUMN IF NOT EXISTS max_uses INT,
  ADD COLUMN IF NOT EXISTS use_count INT DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true NOT NULL;

-- invite_usages: track who accepted which invite (for max_uses and UI)
CREATE TABLE IF NOT EXISTS public.invite_usages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invite_id UUID NOT NULL REFERENCES public.group_invites(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  accepted_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_invite_usages_invite_id ON public.invite_usages(invite_id);
CREATE INDEX IF NOT EXISTS idx_invite_usages_invite_id_accepted_at ON public.invite_usages(invite_id, accepted_at DESC);

ALTER TABLE public.invite_usages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "invite_usages_select_members" ON public.invite_usages
  FOR SELECT USING (
    public.is_group_member((SELECT group_id FROM public.group_invites WHERE id = invite_id))
  );
CREATE POLICY "invite_usages_insert_own" ON public.invite_usages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- participants: link to auth user and avatar
ALTER TABLE public.participants
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS avatar_id TEXT;

-- expenses: multi-currency and base amount
ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS exchange_rate DOUBLE PRECISION DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS base_amount_cents INT;

-- groups: optional icon and color (app display); ensure permission columns exist (older projects may lack them)
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS icon TEXT,
  ADD COLUMN IF NOT EXISTS color INT,
  ADD COLUMN IF NOT EXISTS allow_member_add_participant BOOLEAN DEFAULT true NOT NULL,
  ADD COLUMN IF NOT EXISTS require_participant_assignment BOOLEAN DEFAULT false NOT NULL;

-- Composite indexes for common query patterns (if not already in Migration 1)
CREATE INDEX IF NOT EXISTS idx_expenses_group_id_date_desc ON public.expenses(group_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_participants_group_id_sort_order ON public.participants(group_id, sort_order);

-- Partial index for active invites (optional, helps list-invites-by-group)
CREATE INDEX IF NOT EXISTS idx_group_invites_active ON public.group_invites(group_id) WHERE expires_at > now();
```

### Migration 8: RPC updates (invites)

Run after Migration 7 so `group_invites` and `invite_usages` have the new columns/table. This replaces `create_invite` and `accept_invite` with versions that support label, max_uses, use_count, and invite_usages.

```sql
-- Drop old create_invite (3 args) so only the extended version remains
DROP FUNCTION IF EXISTS public.create_invite(UUID, TEXT, TEXT);

-- =============================================
-- create_invite: extended with label, max_uses, expires_in, created_by
-- =============================================
CREATE OR REPLACE FUNCTION public.create_invite(
  p_group_id UUID,
  p_invitee_email TEXT DEFAULT NULL,
  p_role TEXT DEFAULT 'member',
  p_label TEXT DEFAULT NULL,
  p_max_uses INT DEFAULT NULL,
  p_expires_in TEXT DEFAULT NULL
)
RETURNS TABLE(id UUID, token TEXT) AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_token TEXT;
  v_invite_id UUID;
  v_expires_at TIMESTAMPTZ;
BEGIN
  v_user_id := auth.uid();

  SELECT gm.role INTO v_user_role FROM public.group_members gm
  WHERE gm.group_id = p_group_id AND gm.user_id = v_user_id;

  IF v_user_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can create invites';
  END IF;

  v_token := pg_catalog.encode(extensions.gen_random_bytes(18), 'base64');
  v_token := replace(replace(replace(v_token, '+', ''), '/', ''), '=', '');
  v_token := substr(v_token, 1, 24);

  v_expires_at := now() + COALESCE(p_expires_in::interval, interval '7 days');

  INSERT INTO public.group_invites (
    group_id, token, invitee_email, role, expires_at,
    created_by, label, max_uses, use_count, is_active
  )
  VALUES (
    p_group_id, v_token, p_invitee_email, p_role, v_expires_at,
    v_user_id, p_label, p_max_uses, 0, true
  )
  RETURNING group_invites.id INTO v_invite_id;

  RETURN QUERY SELECT v_invite_id, v_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- accept_invite: record usage, respect max_uses and is_active, delete only when exhausted
-- =============================================
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

  IF p_new_participant_name IS NOT NULL AND p_new_participant_name != '' THEN
    INSERT INTO public.participants (group_id, name, sort_order)
    VALUES (v_group_id, p_new_participant_name,
      (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM public.participants WHERE group_id = v_group_id))
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Security: set search_path on new/updated function signatures
ALTER FUNCTION public.create_invite(UUID, TEXT, TEXT, TEXT, INT, TEXT) SET search_path = '';
ALTER FUNCTION public.accept_invite(TEXT, UUID, TEXT) SET search_path = '';
```

### Migration 9: Security hardening (search_path, revoke/toggle RPCs)

Ensures all invite-related RPCs have `search_path` set and adds `revoke_invite` and `toggle_invite_active` if your project uses them (app calls these). Run after Migration 8.

```sql
-- =============================================
-- revoke_invite: deactivate an invite (owner/admin)
-- =============================================
CREATE OR REPLACE FUNCTION public.revoke_invite(p_invite_id UUID)
RETURNS VOID AS $$
DECLARE
  v_group_id UUID;
  v_user_role TEXT;
BEGIN
  SELECT group_id INTO v_group_id FROM public.group_invites WHERE id = p_invite_id;
  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invite not found';
  END IF;
  SELECT role INTO v_user_role FROM public.group_members
  WHERE group_id = v_group_id AND user_id = auth.uid();
  IF v_user_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can revoke invites';
  END IF;
  UPDATE public.group_invites SET is_active = false WHERE id = p_invite_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- =============================================
-- toggle_invite_active: set is_active on an invite (owner/admin)
-- =============================================
CREATE OR REPLACE FUNCTION public.toggle_invite_active(p_invite_id UUID, p_active BOOLEAN)
RETURNS VOID AS $$
DECLARE
  v_group_id UUID;
  v_user_role TEXT;
BEGIN
  SELECT group_id INTO v_group_id FROM public.group_invites WHERE id = p_invite_id;
  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invite not found';
  END IF;
  SELECT role INTO v_user_role FROM public.group_members
  WHERE group_id = v_group_id AND user_id = auth.uid();
  IF v_user_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'Only owner or admin can toggle invites';
  END IF;
  UPDATE public.group_invites SET is_active = p_active WHERE id = p_invite_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Ensure search_path is set on all other invite/auth-related functions (idempotent)
ALTER FUNCTION public.get_invite_by_token(TEXT) SET search_path = '';
ALTER FUNCTION public.accept_invite(TEXT, UUID, TEXT) SET search_path = '';
DO $$ BEGIN ALTER FUNCTION public.accept_invite(TEXT) SET search_path = ''; EXCEPTION WHEN undefined_function THEN NULL; END $$;
-- 6-arg create_invite: Migration 8 may use TEXT or INTERVAL for last param; set both so one succeeds
DO $$ BEGIN ALTER FUNCTION public.create_invite(UUID, TEXT, TEXT, TEXT, INT, TEXT) SET search_path = ''; EXCEPTION WHEN undefined_function THEN NULL; END $$;
DO $$ BEGIN ALTER FUNCTION public.create_invite(UUID, TEXT, TEXT, TEXT, INT, INTERVAL) SET search_path = ''; EXCEPTION WHEN undefined_function THEN NULL; END $$;
DO $$ BEGIN ALTER FUNCTION public.create_invite(UUID, TEXT, TEXT) SET search_path = ''; EXCEPTION WHEN undefined_function THEN NULL; END $$;
```

### Migration 10: RLS performance (auth initplan and merged groups SELECT)

Recreates policies so `auth.uid()` is evaluated once per query via `(select auth.uid())`, and merges the two groups SELECT policies into one. Run after Migration 9.

```sql
-- =============================================
-- Groups: single SELECT policy (owner or member)
-- =============================================
DROP POLICY IF EXISTS "groups_select" ON public.groups;
DROP POLICY IF EXISTS "groups_select_members" ON public.groups;
DROP POLICY IF EXISTS "groups_select_owner" ON public.groups;
CREATE POLICY "groups_select" ON public.groups
  FOR SELECT USING (
    public.is_group_member(id)
    OR (SELECT auth.uid()) = owner_id
  );

-- =============================================
-- Groups INSERT: use (select auth.uid())
-- =============================================
DROP POLICY IF EXISTS "groups_insert_authenticated" ON public.groups;
CREATE POLICY "groups_insert_authenticated" ON public.groups
  FOR INSERT WITH CHECK ((SELECT auth.uid()) IS NOT NULL AND owner_id = (SELECT auth.uid()));

-- =============================================
-- Group members: auth initplan
-- =============================================
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

-- =============================================
-- Participants INSERT: use (select auth.uid()) where applicable
-- =============================================
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

-- =============================================
-- Invite usages: SELECT with initplan; ensure INSERT policy exists
-- =============================================
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

-- =============================================
-- Device tokens: all policies with (select auth.uid())
-- =============================================
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
```

### Migration 11: Indexes (composite, partial, and FK)

Adds composite/partial indexes for app query patterns and indexes on foreign key columns recommended by the Supabase linter. Run after Migration 10.

```sql
-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_expenses_group_id_date_desc ON public.expenses(group_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_participants_group_id_sort_order ON public.participants(group_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_invite_usages_invite_id_accepted_at ON public.invite_usages(invite_id, accepted_at DESC);
-- Partial index using now() is not allowed (predicate must be IMMUTABLE). Omit if you get an error:
-- CREATE INDEX IF NOT EXISTS idx_group_invites_active ON public.group_invites(group_id) WHERE expires_at > now();

-- Indexes on foreign key columns (performance)
CREATE INDEX IF NOT EXISTS idx_expenses_payer_participant_id ON public.expenses(payer_participant_id);
CREATE INDEX IF NOT EXISTS idx_expenses_to_participant_id ON public.expenses(to_participant_id);
CREATE INDEX IF NOT EXISTS idx_group_invites_created_by ON public.group_invites(created_by);
CREATE INDEX IF NOT EXISTS idx_group_members_participant_id ON public.group_members(participant_id);
CREATE INDEX IF NOT EXISTS idx_groups_treasurer_participant_id ON public.groups(treasurer_participant_id);
CREATE INDEX IF NOT EXISTS idx_groups_owner_id ON public.groups(owner_id);
CREATE INDEX IF NOT EXISTS idx_invite_usages_user_id ON public.invite_usages(user_id);
CREATE INDEX IF NOT EXISTS idx_participants_user_id ON public.participants(user_id);
```

### Migration 12: Groups archive (archived_at)

Adds soft-archive support so the owner can archive a group. Run after Migration 11.

```sql
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;
```

No new RPC or RLS change: existing `groups_update_owner_admin` allows owner/admin to update any column, including `archived_at`.

### Migration 13: merge_participant_with_member (merge manual participant with user)

Lets owner/admin link a manually created participant to an existing group member and set the participant's name/avatar from that user's auth profile. Run after Migration 12.

```sql
-- merge_participant_with_member: link participant to member and set participant name/user_id/avatar from auth.
-- If the member had a different participant linked, that participant is deleted (left-out) when safe:
-- only when no expense has them as payer (to avoid cascading expense deletion).
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

  -- Delete the previously linked participant (left-out) if different and not used as payer in any expense
  IF v_old_participant_id IS NOT NULL AND v_old_participant_id != p_participant_id THEN
    DELETE FROM public.participants
    WHERE id = v_old_participant_id AND group_id = p_group_id
      AND NOT EXISTS (SELECT 1 FROM public.expenses WHERE payer_participant_id = v_old_participant_id);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
```

### Migration 14: Participants left/archived (left_at) and re-join reuse

Adds `left_at` to participants so that when a member leaves or is kicked, their participant is marked left (and can be hidden) while keeping expense history. Re-joining via invite reuses the same participant. Run after Migration 13.

```sql
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
```

**Note:** RLS already allows owner/admin to update participants; `left_at` is included. New RPC `archive_participant` is callable by owner/admin. Grant execute to authenticated if needed: `GRANT EXECUTE ON FUNCTION public.archive_participant(UUID, UUID) TO authenticated;` (typically RPCs are granted in Migration 4 or your project’s RPC grants).

### Migration 15: Receipt images Storage bucket

Expense receipt images are uploaded to Supabase Storage so all group members can see them. The app stores the public URL in `expenses.receipt_image_path`.

1. **Create the bucket in the Dashboard**: Go to **Storage** → **New bucket**. Name: `receipt-images`. Set **Public bucket** to **Yes** (so `getPublicUrl()` works without signed URLs). Optionally set file size limit (e.g. 10 MB) and allowed MIME types (e.g. `image/jpeg`, `image/png`, `image/webp`, `image/heic`).
2. **Apply the migration** (run the SQL in `supabase/migrations/20250224100000_receipt_images_storage_bucket.sql`) to add RLS policies on `storage.objects`:
   - **INSERT**: Authenticated users can upload only into paths whose first folder is a group they belong to (`group_id/expense_id/filename`).
   - **SELECT**: Authenticated users can read objects in groups they belong to.

Path format in the bucket: `{group_id}/{expense_id}/{uuid}.{ext}`.

---

## 4. Configure Authentication

### Email/Password Authentication

Email auth is enabled by default in Supabase. No additional configuration needed.

**Leaked password protection:** Supabase can block sign-up/sign-in with compromised passwords (HaveIBeenPwned). Enable in **Authentication > Settings > Security > Leaked password protection** for better security.

### Magic Link Authentication

Magic links use the same email provider. Configure your SMTP settings in **Authentication > Email Templates** for production use (Supabase's built-in email has rate limits).

### Google OAuth (Optional)

1. Go to [Google Cloud Console](https://console.cloud.google.com/) and create OAuth 2.0 credentials.
2. Set the authorized redirect URI to:
   ```
   https://<your-project-ref>.supabase.co/auth/v1/callback
   ```
3. In Supabase dashboard, go to **Authentication > Providers > Google**.
4. Enable it and paste your Client ID and Client Secret.

### GitHub OAuth (Optional)

1. Go to [GitHub Developer Settings](https://github.com/settings/developers) and create a new OAuth App.
2. Set the authorization callback URL to:
   ```
   https://<your-project-ref>.supabase.co/auth/v1/callback
   ```
3. In Supabase dashboard, go to **Authentication > Providers > GitHub**.
4. Enable it and paste your Client ID and Client Secret.

### Deep Link / Redirect Configuration

For mobile apps, configure the redirect URLs in **Authentication > URL Configuration**:

- **Site URL**: Your production app URL (e.g. `https://your-app-domain.com`). If this is left as `http://localhost:...`, **email verification and magic links** in auth emails will point to localhost. For production, set this to your real domain.
- **Redirect URLs** (add all that you use):
  - Your production URL if using `SITE_URL` in the app (e.g. `https://yourdomain.com`)
  - `io.supabase.hisab://callback` (for native mobile apps)
  - `http://localhost:*` (for local development)

To control the redirect from the app (e.g. when Site URL is wrong), pass `--dart-define=SITE_URL=https://yourdomain.com` when building. The app will send this as `emailRedirectTo` for sign-up, magic link, and resend confirmation. The URL must be in the **Redirect URLs** list above.

---

## 5. Deploy Edge Functions

Hisab uses three Supabase Edge Functions. Deploy them using the Supabase CLI or dashboard.

### invite-redirect

Handles invite link redirects -- sends mobile users to the app deep link and desktop users to the web app.

**File**: `supabase/functions/invite-redirect/index.ts`

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const APP_SCHEME = "io.supabase.hisab";
const WEB_URL = Deno.env.get("SITE_URL") ?? "https://hisab.app";

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const token = url.searchParams.get("token");

  if (!token) {
    return new Response(JSON.stringify({ error: "Missing token parameter" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Validate invite exists (optional, for better error messages)
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    const { data, error } = await supabase.rpc("get_invite_by_token", {
      p_token: token,
    });

    if (error || !data || data.length === 0) {
      return new Response(
        `<html><body><h2>Invalid or expired invite link</h2><p>This invite may have expired or already been used.</p></body></html>`,
        {
          status: 404,
          headers: { "Content-Type": "text/html" },
        }
      );
    }
  } catch (_) {
    // If validation fails, still redirect -- app will handle the error
  }

  // Redirect to app deep link
  const appLink = `${APP_SCHEME}://invite?token=${encodeURIComponent(token)}`;
  const webLink = `${WEB_URL}/invite?token=${encodeURIComponent(token)}`;

  // User-Agent detection: mobile gets deep link, desktop gets web
  const ua = req.headers.get("user-agent") ?? "";
  const isMobile = /android|iphone|ipad|mobile/i.test(ua);
  const redirectTo = isMobile ? appLink : webLink;

  return new Response(null, {
    status: 302,
    headers: {
      Location: redirectTo,
      "Cache-Control": "no-cache",
    },
  });
});
```

**Deploy with CLI**:
```bash
supabase functions deploy invite-redirect --no-verify-jwt
```

> **Note**: `--no-verify-jwt` is required because invite links are accessed by unauthenticated users clicking a shared URL.

### telemetry

Accepts anonymous usage telemetry events.

**File**: `supabase/functions/telemetry/index.ts`

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json();
    const { event, timestamp, data } = body;

    if (!event) {
      return new Response(JSON.stringify({ error: "Missing 'event' field" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    const { error } = await supabase.from("telemetry").insert({
      event,
      timestamp: timestamp ?? new Date().toISOString(),
      data: data ?? null,
    });

    if (error) {
      console.error("Telemetry insert error:", error);
      return new Response(JSON.stringify({ error: "Insert failed" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        Connection: "keep-alive",
      },
    });
  } catch (e) {
    console.error("Telemetry error:", e);
    return new Response(JSON.stringify({ error: "Internal error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
```

**Deploy with CLI**:
```bash
supabase functions deploy telemetry --no-verify-jwt
```

> **Note**: `--no-verify-jwt` allows anonymous telemetry without requiring authentication.

### send-notification

Sends FCM push notifications to group members when expenses are created/updated or new members join. Called by the database trigger (Migration 6) via `pg_net`. The function queries `group_members` and `device_tokens` for the group (excluding the actor), then sends FCM HTTP v1 messages with `notification` (title/body) and `data.group_id` so the Flutter app can display and navigate to the group on tap.

**Prerequisites:**
1. Create a Firebase project and add apps for Android, iOS, and Web.
2. Generate a service account key (Project Settings > Service accounts > Generate new private key).
3. Set the following Supabase secrets:

```bash
supabase secrets set FCM_PROJECT_ID=your-firebase-project-id
supabase secrets set FCM_SERVICE_ACCOUNT_KEY='{"type":"service_account",...}'
```

4. Store the Supabase service role key in Vault (for the database trigger):

```sql
-- Run in SQL Editor (replace with your actual service role key from Dashboard > Settings > API)
SELECT vault.create_secret('YOUR_SERVICE_ROLE_KEY_HERE', 'service_role_key');
```

**File**: `supabase/functions/send-notification/index.ts`

The implementation in the repo uses the trigger payload (`group_id`, `actor_user_id`, `action`, `expense_title`, `amount_cents`, `currency_code`) to build a notification title/body, fetches FCM tokens for other group members from `device_tokens`, obtains an OAuth2 access token from the Firebase service account, and sends one FCM v1 request per token. The Flutter app expects `message.notification` (title, body) and `message.data.group_id` (string) for tap navigation; see `lib/core/services/notification_service.dart`.

**Deploy with CLI**:
```bash
supabase functions deploy send-notification --no-verify-jwt
```

> **Note**: `--no-verify-jwt` is used because the function validates the service role key in the request header (sent by the database trigger via pg_net).

#### Push notifications: end-to-end flow and verification

The following describes the full pipeline so you can verify or debug each step.

**Flow (expense add/edit):**

1. **Flutter app** (online): User adds or edits an expense → [PowerSyncRepository](lib/core/repository/powersync_repository.dart) writes to Supabase `expenses` via `Supabase.instance.client` (authenticated). Offline writes are queued in `pending_writes` and pushed later by [DataSyncService](lib/core/database/database_providers.dart) using the same client, so the trigger runs with `auth.uid()` set.
2. **Supabase Postgres**: `AFTER INSERT OR UPDATE ON expenses` fires trigger `notify_on_expense_change` → function `notify_group_activity()` runs. It reads `v_supabase_url` (must be your project URL, not `YOUR_SUPABASE_URL`) and the service role key from **Vault** (`service_role_key`). If either is missing, it logs and returns without calling the edge function.
3. **pg_net**: `net.http_post` sends a POST to `{v_supabase_url}/functions/v1/send-notification` with JSON body `group_id`, `actor_user_id`, `action`, `expense_title`, `amount_cents`, `currency_code` and header `Authorization: Bearer <service_role_key>`.
4. **Edge function `send-notification`**: Validates the Bearer token against `SUPABASE_SERVICE_ROLE_KEY`, then uses `FCM_PROJECT_ID` and `FCM_SERVICE_ACCOUNT_KEY` to obtain a Google OAuth2 access token and send FCM HTTP v1 messages to all group members’ device tokens (from `device_tokens`) except the actor. Each message includes `notification: { title, body }` and `data: { group_id }` (string).
5. **Flutter app** (on other devices): Receives the message via Firebase; [NotificationService](lib/core/services/notification_service.dart) displays it and, on tap, navigates to the group using `message.data['group_id']`.

**Verification checklist:**

| Step | Where to check | What to verify |
|------|----------------|----------------|
| 1. Edge function deployed | Dashboard → Edge Functions | `send-notification` is listed and ACTIVE. |
| 2. Edge function secrets | Dashboard → Project Settings → Edge Functions → Secrets | `FCM_PROJECT_ID` and `FCM_SERVICE_ACCOUNT_KEY` are set. Use the same Firebase project as your Flutter app (e.g. `google-services.json` / web config). |
| 3. Vault secret | SQL Editor: `SELECT name FROM vault.decrypted_secrets WHERE name = 'service_role_key';` | One row returned. If not, run `SELECT vault.create_secret('<your-service-role-key>', 'service_role_key');` (key from Settings → API). |
| 4. Trigger URL | Database → Functions → `notify_group_activity` → view source | `v_supabase_url` is your project URL (e.g. `https://xxxxxxxxxxxxx.supabase.co`), not `YOUR_SUPABASE_URL`. If wrong, re-run the Migration 6 function with the correct URL. |
| 5. pg_net enabled | Database → Extensions | `pg_net` (schema `extensions`) is installed. |
| 6. Triggers exist | Database → Tables → `expenses` → Triggers | `notify_on_expense_change` (AFTER INSERT OR UPDATE). Similarly `group_members` has `notify_on_member_join`. |
| 7. Device tokens | Table Editor → `device_tokens` | Rows exist for users who should receive notifications. The app registers tokens when the user is signed in, has notifications enabled in settings, and has granted permission. On web, `FCM_VAPID_KEY` must be set at build time. |
| 8. Flutter | App Settings | Notifications toggle is on; app has requested and been granted notification permission. |

**Testing delivery:** You can send a test FCM message to a registration token (e.g. from `device_tokens`) using the Firebase Console (Cloud Messaging) or an API client. If the device receives that test but not expense-triggered notifications, the issue is upstream (trigger, Vault, or edge function secrets/logs).

---

## 6. Configure the Flutter App

The app uses `--dart-define` parameters for build-time configuration. No hardcoded secrets are needed in the codebase.

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `SUPABASE_URL` | Your Supabase project URL | `https://xxxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Your Supabase anon/public key | `eyJhbGci...` |
| `INVITE_BASE_URL` | Optional. Custom domain for invite links (no extra hosting). See [Custom Domains](https://supabase.com/docs/guides/platform/custom-domains). | `https://invite.yourdomain.com` |
| `SITE_URL` | Optional. Redirect URL for auth emails (magic link, sign-up confirmation). Stops verification links from using localhost. Must be in Supabase Redirect URLs. | `https://yourdomain.com` |
| `FCM_VAPID_KEY` | Optional. VAPID key for FCM web push notifications. Get from Firebase Console > Project Settings > Cloud Messaging > Web Push certificates. | `BPm...` |

### Running the App

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
```

### Running Without Supabase (Offline Only)

Simply run without any `--dart-define` parameters:

```bash
flutter run
```

The app will operate in **local-only mode** -- all data stays on-device, and authentication, sync, invites, and telemetry features are disabled.

### VS Code / Cursor Launch Configuration

Add to `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Hisab (Online)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=SUPABASE_URL=https://xxxxx.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=eyJhbGci..."
      ]
    },
    {
      "name": "Hisab (Offline Only)",
      "request": "launch",
      "type": "dart"
    }
  ]
}
```

---

## 7. Verify the Setup

After completing all steps:

1. **Database**: Go to Supabase Table Editor and verify core tables exist: `groups`, `group_members`, `participants`, `expenses`, `expense_tags`, `group_invites`, `telemetry`, `public.device_tokens`, and (after Migration 7) `invite_usages`.

2. **RLS**: Go to **Authentication > Policies** and verify each table has its RLS policies enabled.

3. **Functions**: Go to **Database > Functions** and verify RPC functions exist:
   - `handle_updated_at`, `get_user_role`, `is_group_member`, `get_my_participant_id`
   - `get_invite_by_token`, `accept_invite`, `create_invite`, `revoke_invite`, `toggle_invite_active`
   - `transfer_ownership`, `leave_group`, `kick_member`, `update_member_role`, `assign_participant`, `merge_participant_with_member`
   - `get_delete_my_data_preview`, `delete_my_data` (for Settings > Delete cloud data; see migration `20250222100000_delete_my_data_and_leave_group_updates.sql`. `leave_group` is updated in that migration to clear treasurer when the leaving member is treasurer and to delete the group when the leaving member is the only member.)

4. **Edge Functions**: Go to **Edge Functions** and verify `invite-redirect`, `telemetry`, and `send-notification` are deployed and active (for push notifications, also set `FCM_PROJECT_ID` and `FCM_SERVICE_ACCOUNT_KEY` secrets; see Section 5).

5. **Auth**: Try signing up with email/password in the app. Check the Supabase **Authentication > Users** page to confirm the user was created.

6. **Sync**: After signing in, create a group in the app. Check the Supabase Table Editor to verify the group appears in the `groups` table with the correct `owner_id`.

### Current schema reference (verified via Supabase MCP)

The following matches the live schema when Migrations 1–8 (or equivalent) are applied. Use **Supabase MCP** `list_tables` with your `project_id` to verify your project.

| Table | Key columns (public schema) |
|-------|-----------------------------|
| **groups** | id, name, currency_code, owner_id, settlement_method, treasurer_participant_id, settlement_freeze_at, settlement_snapshot_json, allow_member_add_expense, allow_member_add_participant, allow_member_change_settings, require_participant_assignment, allow_expense_as_other_participant, icon, color, created_at, updated_at |
| **participants** | id, group_id, name, sort_order, user_id, avatar_id, left_at, created_at, updated_at |
| **group_members** | id, group_id, user_id, role, participant_id, joined_at |
| **expenses** | id, group_id, payer_participant_id, amount_cents, currency_code, exchange_rate, base_amount_cents, title, description, date, split_type, split_shares_json, type, to_participant_id, tag, line_items_json, receipt_image_path, created_at, updated_at |
| **expense_tags** | id, group_id, label, icon_name, created_at, updated_at |
| **group_invites** | id, group_id, token, invitee_email, role, created_at, expires_at, created_by, label, max_uses, use_count, is_active |
| **invite_usages** | id, invite_id, user_id, accepted_at |
| **device_tokens** | id, user_id, token, platform, locale, created_at, updated_at |
| **telemetry** | id, event, timestamp, data |

**Note:** Existing projects that lack `allow_member_add_participant` or `require_participant_assignment` on `groups` will get them when you run Migration 7 (it uses `ADD COLUMN IF NOT EXISTS`).

### Verifying with Supabase MCP

If you use the [Supabase MCP](https://supabase.com/docs/guides/getting-started/mcp) (e.g. in Cursor), you can verify schema and run advisors:

- **list_tables** with your `project_id`: lists tables, columns, RLS, row counts.
- **get_advisors** with `type: "security"` and `type: "performance"`: returns lints (e.g. function `search_path`, unindexed FKs, RLS auth initplan). Re-run after applying migrations to confirm issues are resolved.

The "Current schema reference" table above can be re-verified with `list_tables`.

---

## 8. Architecture Overview

```
+------------------+     +------------------+
|   Flutter App    |     |    Supabase      |
|                  |     |                  |
| Local SQLite     |     | Postgres DB      |
| (PowerSync pkg)  |     | (+ RLS policies) |
|                  |     |                  |
| DataSyncService  |<--->| REST API         |
| (fetch/push)     |     |                  |
|                  |     |                  |
| Supabase Client  |<--->| Auth             |
| (auth + RPC)     |     | Edge Functions   |
+------------------+     +------------------+
```

### Data Flow

- **Reads**: All reads come from local SQLite (instant, works offline).
- **Writes (online)**: Writes go to Supabase first, then update local SQLite cache.
- **Writes (temporarily offline)**: Expense creation queued in `pending_writes` table; pushed when connectivity returns.
- **Sync**: `DataSyncService` performs full fetches from Supabase, pushes pending writes, and periodic refreshes (every 5 min).
- **Complex operations**: RPC functions (invites, ownership transfer, etc.) are called directly on Supabase when online. These are unavailable in offline/local-only mode.
- **Auth**: Supabase Auth handles all authentication.

### Permission Model

| Role | Capabilities |
|------|-------------|
| **Owner** | Full control: CRUD all data, manage members, change settings, delete group, transfer ownership |
| **Admin** | Manage members, create invites, CRUD expenses/participants/tags, change group settings |
| **Member** | Conditional: add expenses (if `allow_member_add_expense`), add participants (if `allow_member_add_participant`), change settings (if `allow_member_change_settings`). When `allow_expense_as_other_participant` is false, members may only create/update expenses where they are the payer (payer_participant_id = their own participant). |

### Schema and behavior notes

- **device_tokens**: Table lives in `public.device_tokens`. One row per (user_id, token); optional `locale` (e.g. `en`, `ar`) is sent by the app on token register/refresh for language-aware push notifications; `updated_at` is maintained by trigger. RLS restricts access to the current user’s rows only.
- **groups.owner_id**: References `auth.users(id)` with `ON DELETE SET NULL`. If an auth user is deleted (e.g. account removal), their groups are not deleted; `owner_id` becomes NULL. Ownership can be reassigned via `transfer_ownership` or `leave_group` (oldest member becomes owner). Consider documenting this for support.
- **telemetry**: Append-only table; no SELECT policy (insert-only for analytics). No built-in retention; the table can grow without bound. For production, consider a retention strategy (e.g. periodic delete of rows older than N months, or partitioning by month and dropping old partitions). Add an index on `(timestamp)` or `(event, timestamp)` if you run reporting queries.

---

## 9. Troubleshooting

### "App works offline but nothing syncs"

- Verify both `--dart-define` parameters are set correctly.
- Check that the Supabase project is active in the dashboard.
- Ensure the user is authenticated (signed in).

### "RLS policy violation" errors

- Check that the user is authenticated (`auth.uid()` is not null).
- Verify the user has the correct role for the operation.
- For new group creation, ensure `owner_id` matches `auth.uid()`.

### "Function not found" errors

- Ensure all 4 migrations were applied in order.
- Check that the function exists in **Database > Functions**.
- Verify the function signature matches (parameter types matter).

### Edge Function errors

- Check **Edge Functions > Logs** in the Supabase dashboard.
- Verify `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` environment variables are automatically available (they are by default in Supabase Edge Functions).

### OAuth redirect issues

- Verify the redirect URL is added to **Authentication > URL Configuration > Redirect URLs**.
- For mobile, ensure the app scheme (`io.supabase.hisab`) is registered in your Android/iOS configuration.
- For web, ensure the site URL matches your deployment URL.

### Push notifications not received

- **Checklist:** Follow the [Push notifications: end-to-end flow and verification](#push-notifications-end-to-end-flow-and-verification) table in Section 5. Common causes:
  - **Vault:** `service_role_key` not created or wrong name → trigger never calls the edge function (check Postgres logs for "service_role_key not found in vault").
  - **Trigger URL:** Still set to `YOUR_SUPABASE_URL` → pg_net POST fails; fix by re-creating `notify_group_activity()` with the real project URL.
  - **Edge function secrets:** `FCM_PROJECT_ID` or `FCM_SERVICE_ACCOUNT_KEY` missing or invalid → function returns 500 or FCM rejects sends; check Edge Functions → send-notification → Logs.
  - **No device tokens:** Recipients must be signed in with notifications enabled and permission granted; tokens are stored in `device_tokens`. On web, `FCM_VAPID_KEY` must be set at build time or the web token is never registered.
- **Verify FCM separately:** Send a test message to a token from `device_tokens` via Firebase Console (Cloud Messaging) or the FCM API. If that works but expense-triggered notifications do not, the problem is the Supabase pipeline (trigger/Vault/edge function).

### "Could not find the 'archived_at' column of 'groups'" (PGRST204)

- **Cause:** PostgREST’s schema cache doesn’t include `archived_at` because [Migration 12](#migration-12-groups-archive-archived_at) has not been applied.
- **Fix:** In the Supabase **SQL Editor**, run Migration 12:
  ```sql
  ALTER TABLE public.groups
    ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;
  ```
- After this, group name/icon/color changes and archive/unarchive will work. The app also omits `archived_at` from group updates when the column is missing so that name/icon/color changes can succeed before the migration.

---

## 10. Testing

Run the test suite with:

```bash
flutter test
```

**What is covered**

- **Local database** (`test/local_database_test.dart`): PowerSync repository CRUD and streams with no Supabase (local-only mode). Requires the PowerSync native binary to run; see below.
- **Sync** (`test/sync_test.dart`): `SyncEngine` fetch and push using a fake backend. Verifies that data from the backend is written correctly to the local DB and that pending writes are applied and removed. Requires the PowerSync native binary.
- **Supabase repository** (`test/supabase_repository_test.dart`): Local-only repository behavior (no Supabase client). Full integration tests against a real Supabase project are not included; run those manually with `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...` if needed.

**PowerSync native binary (for local DB and sync tests)**

Tests that use [PowerSyncDatabase](https://pub.dev/documentation/powersync/latest/powersync/PowerSyncDatabase-class.html) need the `powersync-sqlite-core` native library. Without it, those tests are skipped and the suite still passes.

1. Download the binary for your OS from [powersync-sqlite-core Releases](https://github.com/powersync-ja/powersync-sqlite-core/releases).
2. Rename it: `libpowersync_x64.so` → `libpowersync.so` (Linux), `libpowersync_aarch64.dylib` → `libpowersync.dylib` (macOS), or `powersync_x64.dll` → `powersync.dll` (Windows).
3. Place the renamed file in the project root directory.

See [PowerSync Flutter unit testing](https://docs.powersync.com/client-sdk-references/flutter/unit-testing) for details.
