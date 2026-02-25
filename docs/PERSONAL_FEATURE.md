# Personal (my-expenses-only) feature

This document describes the **personal** mode in Hisab: a minimal, single-user view for tracking your own expenses and optional budget, with the ability to convert to or from a shared group.

## Overview

- **Personal** = one group with `is_personal == true`, a single participant (you), and an optional budget. UI is reduced: no Balance or People tabs, no split or invite; just **My budget** (optional amount) and **My expenses** (list).
- **Group** = the full experience: participants, splits, invites, Balance tab, People tab.
- Users can **convert** between the two: **Share as group** (personal → group) and **Use as personal** (group → personal when there is only one member).

The same domain entity (`Group`) and the same pages (detail, settings, expense form) are used for both; behavior is branched on `group.isPersonal` and participant count where needed.

## Data model

### Domain

- **`lib/domain/group.dart`**
  - `bool isPersonal` (default `false`)
  - `int? budgetAmountCents` (nullable; used for “My budget” when personal)
  - Both are in `copyWith`; `copyWith(clearBudgetAmountCents: true)` sets budget to `null` (used when clearing budget in settings).

### Local DB (PowerSync)

- **`lib/core/database/powersync_schema.dart`**
  - `groups` table: `Column.integer('is_personal')`, `Column.integer('budget_amount_cents')` (nullable).

### Cloud DB (Supabase)

- **Migration 16** (`supabase/migrations/20250225000000_groups_is_personal_and_budget.sql`):
  - `is_personal BOOLEAN DEFAULT false NOT NULL`
  - `budget_amount_cents INT` (nullable)
- Documented in [SUPABASE_SETUP.md](SUPABASE_SETUP.md) under “Migration 16”.

### Repository and sync

- **`lib/core/repository/group_repository.dart`**  
  - `create(..., { bool isPersonal = false, int? budgetAmountCents })`
- **`lib/core/repository/powersync_repository.dart`**
  - `_groupFromRow`: reads `is_personal` (0/1 → bool), `budget_amount_cents` (nullable int).
  - `create()`: writes both to Supabase and local INSERT.
  - `update()`: includes both in Supabase PATCH and local UPDATE.
- **`lib/core/database/sync_engine.dart`**  
  - Full fetch: INSERT into local `groups` includes `is_personal` and `budget_amount_cents`; uses `(g['is_personal'] ?? false) == true` and `(g['budget_amount_cents'] as num?)?.toInt()` for backward compatibility.

## User flows

### Create

- **Home** → tap or long-press the **+** FAB → modal with **Create group** and **Create personal**.
- **Create personal** → `GroupCreatePage(isPersonal: true)` (route `/groups/create-personal`): 3 steps (name+currency, icon+color, summary). No participants step; `repo.create(..., isPersonal: true, initialParticipants: [])`.
- **Create group** → same page with `isPersonal: false`; 4 steps including participants.

### Detail (group detail page)

- **Personal:** Single column: optional archived banner → **My budget** header (budget or “—”, total spent, theme-aware color when near/over budget) → expense list (one summary card “My expenses”) → list of expenses. No tabs; no Invite in app bar; FAB = add expense only.
- **Group:** Unchanged: Expenses | Balance | People tabs, Invite button when owner/admin, FAB by tab (add expense / add participant).

### Expense form

- **Personal:** Payer fixed to the single participant (you); split section hidden. Save still builds one share for that participant.
- **Group:** Full form (payer choice, split type, split section).

### Settings (group settings page)

- **Personal:** Profile (name, icon, color), Currency, **My budget** (editable row; tap to set/clear), Danger zone: **Archive** (if online), **Delete**, **Share as group**. No Settlement, Permissions, or Invite sections.
- **Group:** Full settings; when participant count is 1, Danger zone also shows **Use as personal**.

### Convert

- **Share as group (personal → group):** Confirm → `update(group.copyWith(isPersonal: false))`. Full UI (tabs, Invite) appears.
- **Use as personal (group → personal):** Only when there is one participant. Confirm → revoke all active invites for the group → `update(group.copyWith(isPersonal: true))`.

## Code locations

| Area | File(s) |
|------|--------|
| Domain | `lib/domain/group.dart` |
| Schema | `lib/core/database/powersync_schema.dart`, `lib/core/database/sync_engine.dart` |
| Repo | `lib/core/repository/group_repository.dart`, `lib/core/repository/powersync_repository.dart` |
| Routes | `lib/core/navigation/route_paths.dart` (`groupCreatePersonal`), `lib/core/navigation/app_router.dart` |
| Home | `lib/features/home/pages/home_page.dart` (modal, two sections: Personal / Groups) |
| Create | `lib/features/groups/pages/group_create_page.dart` (`isPersonal`, 3 vs 4 steps) |
| Detail | `lib/features/groups/pages/group_detail_page.dart` (branch on `widget.group.isPersonal`; `_PersonalBudgetHeader`, single view vs tabs) |
| Expense form | `lib/features/expenses/pages/expense_form_page.dart` (`group.isPersonal` → restrict payer, hide split section) |
| Settings | `lib/features/groups/pages/group_settings_page.dart` (My budget row, danger zone, convert actions, invite revoke on Use as personal) |
| Providers | `lib/features/groups/providers/groups_provider.dart` (`personalGroupsProvider`, `sharedGroupsProvider`; home uses main `groupsProvider` and splits list by `isPersonal`) |
| Backup | `lib/features/settings/backup_helper.dart` (`_groupToMap` / `_mapToGroup` include `isPersonal`, `budgetAmountCents`); restore in `lib/features/settings/pages/settings_page.dart` passes them into `groupRepo.create(...)` |

## Backup and restore

- **Export:** `_groupToMap` includes `'isPersonal': g.isPersonal` and `'budgetAmountCents': g.budgetAmountCents`.
- **Import:** `_mapToGroup` reads them; missing keys default to `false` and `null` for old backups.
- **Restore:** When re-creating groups from backup, `groupRepo.create(...)` is called with `icon`, `color`, `isPersonal`, and `budgetAmountCents` so restored groups keep their type and budget.

## Localization

Translation keys used for the personal feature (in `assets/translations/en.json` and `ar.json`):

- `personal`, `no_personal`, `add_first_personal`
- `create_personal`, `create_group`
- `my_budget`, `my_expenses`, `budget_amount`, `budget_updated`, `clear`
- `share_as_group`, `share_as_group_confirm`, `share_as_group_done`
- `use_as_personal`, `use_as_personal_confirm`, `use_as_personal_done`

## What is lost in conversion

### Personal → Group (Share as group)

**Nothing is removed.** The app only sets `is_personal = false` on the group row. All of the following are kept:

- Name, currency, icon, color
- The single participant and all expenses
- **Budget amount** — `budget_amount_cents` stays in the DB; the group UI does not show “My budget”, but if you convert back to personal, the budget value is still there
- Settlement method, treasurer, freeze, permissions (all remain; they apply again when used as a group)

### Group → Personal (Use as personal)

**Only one thing is effectively lost:** the ability to use existing invite links.

- **Invites:** All **active** invite links for the group are **revoked** before converting. Revoked invites remain in the DB (they show as “Revoked” in Invite management) but can no longer be used to join. You can create new invites after converting back to a group.
- **Preserved:** Group id, name, currency, icon, color, the single participant, all expenses, settlement method, treasurer, permissions, and any other group row fields. They stay in the database; the personal UI simply hides Balance, People, and Invite. If you later “Share as group” again, those settings are still in effect.

Summary: Personal↔Group only toggles `is_personal` and (when going to personal) revokes active invites. No participants or expenses are deleted.

### Can others see my personal if it was converted from a group? Will they have it as “personal” under their account?

**No.** Only you can see it. They do **not** have that group under their account at all (not as group, not as personal).

- You can only **Use as personal** when there is **one participant** (you). So at conversion time you are the only member left.
- The app (and Supabase) decide which groups you see by **group membership**: you only sync and see groups where you have a row in `group_members`. After converting to personal, only you have a row for that group.
- Anyone who was in the group and then **left** is removed from `group_members`. When their app next syncs, the sync engine only fetches groups they are still a member of; that group is no longer in the set, so it is removed from their local data. So they don’t see it as “personal” under them—they don’t see the group at all.
- Converting to personal does not add or remove members; it only sets `is_personal = true` and revokes invite links. So no one else gains or keeps access.

## Edge cases and safety

- **Convert to personal:** Only allowed when participant count is 1; all active invites for the group are revoked before setting `isPersonal: true`.
- **Budget:** Null or zero is shown as “—”; user can set or clear in settings (clear uses `copyWith(clearBudgetAmountCents: true)`).
- **Existing groups:** Unchanged; `isPersonal` defaults to `false` everywhere (schema, sync, backup parse).
- **Local-only:** Create personal, add expense, set budget, delete, and Share as group all work without Supabase.

## Related docs

- [SUPABASE_SETUP.md](SUPABASE_SETUP.md) — Migration 16 (groups personal and budget)
- [CODEBASE.md](CODEBASE.md) — Data layer, sync, feature modules
