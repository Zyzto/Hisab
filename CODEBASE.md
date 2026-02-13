# Hisab Codebase Overview

**Hisab** — Group expense splitting and settle-up app. Built with Flutter, Riverpod, GoRouter, and Supabase (auth, database, edge functions). Uses local SQLite (via PowerSync package) for offline-first data storage.

---

## Project Structure

### `lib/` — Flutter App

| Path | Purpose |
|------|---------|
| `main.dart` | Entry point — Supabase init, local SQLite init, OAuth redirect handling, ProviderScope |
| `app.dart` | Root widget — MaterialApp.router, theming, RTL support, DataSyncService watcher |
| `core/navigation/app_router.dart` | GoRouter — onboarding redirect, shell route, groups/expenses routes |
| `core/navigation/main_scaffold.dart` | Main scaffold with floating nav bar and sync status icon |
| `core/auth/auth_service.dart` | Supabase Auth — sign-in/out, OAuth, magic link |
| `core/auth/auth_providers.dart` | Riverpod providers for auth state, session, user profile |
| `core/auth/sign_in_sheet.dart` | Shared sign-in bottom sheet (email, magic link, Google, GitHub) |
| `core/constants/supabase_config.dart` | `supabaseUrl`, `supabaseAnonKey`, optional `inviteLinkBaseUrl` (from `--dart-define`) |
| `core/constants/app_config.dart` | Telemetry endpoint, report URL |
| `core/database/powersync_schema.dart` | Local SQLite schema (mirrors Supabase tables + pending_writes queue) |
| `core/database/database_providers.dart` | `PowerSyncDatabase` provider, `DataSyncService` (fetch/push/refresh) |
| `core/services/connectivity_service.dart` | Network connectivity detection, SyncStatus for UI |
| `core/services/migration_service.dart` | Local→Online data migration when switching modes |
| `core/widgets/sync_status_icon.dart` | Connection status indicator (cloud icons) |

### `lib/domain/`

Domain models: `Group`, `Participant`, `Expense`, `ExpenseTag`, `GroupMember`, `GroupInvite`, `SettlementTransaction`, `SplitType`, etc.

### `lib/features/`

| Feature | Contents |
|---------|----------|
| `home/` | Home routes |
| `groups/` | GroupCreatePage, GroupDetailPage, GroupSettingsPage, InviteAcceptPage, invite_link_sheet |
| `expenses/` | ExpenseFormPage, ExpenseDetailPage, split/category widgets |
| `balance/` | Balance list, settlement rows, record settlement sheet |
| `onboarding/` | Onboarding flow |
| `settings/` | Settings, backup, logs, migration progress dialog |

### `lib/core/repository/`

Repository pattern: `PowerSyncGroupRepository`, `PowerSyncParticipantRepository`, `PowerSyncExpenseRepository`, etc.

- **Local-Only mode**: Direct SQLite reads/writes, no restrictions.
- **Online + connected**: Write to Supabase first, then update local cache.
- **Online + temporarily offline**: Expense creation queued in `pending_writes` table for later push.
- **Reads**: Always from local SQLite (fast, reactive via `watch()` streams).
- Complex multi-table operations use Supabase RPC functions when online.

`repository_providers.dart` provides all repository instances with connectivity and mode flags.

---

## Two User Modes

| Mode | Behavior |
|------|----------|
| **Local-Only** (toggle ON) | Everything works locally — full CRUD, settlement, no network calls |
| **Online** (toggle OFF) | Supabase as source of truth, local SQLite as cache, DataSyncService manages sync |

### Switching Modes

- **Local → Online**: Sign in → `MigrationService` pushes local data to Supabase → switch to online
- **Online → Local**: Disconnect and stop syncing; cached data remains available locally

### Record Settlement

Tap a settlement suggestion ("A → B $50") in the balance view to record the payment. Creates a `TransactionType.transfer` expense that zeroes out the computed debt.

---

## Configuration

- **`supabase_config.dart`**: Reads `SUPABASE_URL`, `SUPABASE_ANON_KEY` from `--dart-define`.
- **`app_config.dart`**: Derives telemetry endpoint from Supabase URL.
- **Supabase Dashboard**: Auth providers (email, Google, GitHub), redirect URLs.

See [SUPABASE_SETUP.md](SUPABASE_SETUP.md) for full backend setup and [CONFIGURATION.md](CONFIGURATION.md) for quick reference.

---

## Key Dependencies

| Category | Packages |
|----------|----------|
| State | `flutter_riverpod`, `riverpod_annotation` |
| Navigation | `go_router` |
| Backend | `supabase_flutter` |
| Local Database | `powersync` (SQLite engine) |
| Connectivity | `connectivity_plus` |
| Localization | `easy_localization` |
| Date/Currency | `intl` |
| Receipt | `image_picker`, `google_mlkit_text_recognition` |
| AI | `langchain_google`, `langchain_openai` |
| Other | `file_picker`, `pretty_qr_code`, `uuid` |

---

## Supabase Backend

The backend is entirely managed through Supabase. Database schema, RLS policies, and RPC functions are applied as migrations (see [SUPABASE_SETUP.md](SUPABASE_SETUP.md)).

| Component | Purpose |
|-----------|---------|
| Postgres tables | `groups`, `group_members`, `group_invites`, `participants`, `expenses`, `expense_tags`, `telemetry` |
| RLS policies | Row-level security enforcing group membership and role-based access |
| RPC functions | `accept_invite`, `transfer_ownership`, `leave_group`, `kick_member`, `create_invite`, etc. |
| Edge Functions | `invite-redirect` (deep link redirect), `telemetry` (anonymous event collection) |
| Auth | Email/password, magic link, Google OAuth, GitHub OAuth |

## Data Sync Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌──────────────┐
│  Flutter App     │    │  Local SQLite │    │   Supabase   │
│  (Repositories)  │───>│  (PowerSync)  │    │   Postgres   │
│                  │<───│              │    │              │
└─────────────────┘    └──────┬───────┘    └──────┬───────┘
                              │                    │
                     ┌────────┴────────────────────┴────────┐
                     │         DataSyncService               │
                     │  - Full fetch on connect               │
                     │  - Push pending_writes on reconnect    │
                     │  - Periodic refresh (5 min)            │
                     └────────────────────────────────────────┘
```
