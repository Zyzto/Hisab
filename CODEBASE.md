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

#### Participant–Member Auto-Link

`Participant` and `GroupMember` remain separate tables but are automatically linked:

- **Join**: When a user creates a group or accepts an invite, a `Participant` is auto-created with `user_id` set to the auth user and `participant_id` set on the member row.
- **Leave/Kick**: Only the `group_members` row is deleted. The `Participant` stays (with `user_id` intact) so expense history is preserved. The "People" tab shows them as "left".
- **Rejoin**: If the same user accepts a new invite, the backend detects the existing `Participant` (by `group_id` + `user_id`) and re-links instead of creating a duplicate.
- **Non-person participants**: Participants with `user_id = null` (e.g. "Cash", "Hotel") can still be added manually.

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

## Language / Locale Architecture

The app supports English (`en`) and Arabic (`ar`) with full RTL support. Locale state is managed through a pipeline that keeps persistence, translation, and UI in sync on the same frame.

### State Flow

| Layer | Component | Role |
|-------|-----------|------|
| Persistence | `languageSettingDef` (key `'language'`) in SharedPreferences via `flutter_settings_framework` | Source of truth, survives restarts |
| Riverpod | `languageProvider` | Exposes the stored value reactively |
| Bridge | `_LocaleSync` widget (`main.dart`) | Watches `languageProvider`, calls `context.setLocale()` via `addPostFrameCallback` when value differs from `context.locale` |
| Translation | `EasyLocalization` (`saveLocale: false`) | Provides `context.localizationDelegates`, `context.supportedLocales`, and `context.locale`. Does NOT persist locale itself |
| UI | `App` widget (`app.dart`) | Reads locale exclusively from `context.locale` for both `locale:` param and RTL directionality |
| Router | `localeRefreshNotifier` (`app_router.dart`) | Listens to `languageProvider`, fires `ValueNotifier` so GoRouter re-evaluates redirects |

### How a Language Switch Works

1. User picks a language (settings page or onboarding).
2. Settings framework writes `'language'` key to SharedPreferences.
3. `languageProvider` rebuilds (Riverpod).
4. `_LocaleSync.build` runs, detects `context.locale != languageProvider`, schedules `context.setLocale(newLocale)` for after the current frame.
5. `localeRefreshNotifier` fires, GoRouter re-evaluates redirects.
6. On the next frame, `context.setLocale` runs. EasyLocalization updates its state and rebuilds its entire subtree.
7. `App.build` runs with consistent `context.locale`, `context.localizationDelegates`, and RTL directionality — all from the same EasyLocalization state.

### Key Invariants

- **`App` never watches `languageProvider` directly.** It reads locale only from `context.locale` (EasyLocalization). This prevents a one-frame mismatch where `locale:` and `localizationDelegates` disagree.
- **`_LocaleSync` is the sole bridge** from Riverpod to EasyLocalization. No other widget should call `context.setLocale()` directly.
- **`EasyLocalization` uses `saveLocale: false`** — persistence is handled entirely by the settings framework (SharedPreferences). The `startLocale` is read from settings on app startup in `main()`.

### Files

| File | Locale role |
|------|-------------|
| `lib/main.dart` | `_LocaleSync` widget, `startLocale` initialization |
| `lib/app.dart` | `MaterialApp.router` with `locale: context.locale`, RTL `Directionality` builder |
| `lib/features/settings/providers/settings_framework_providers.dart` | `languageProvider` |
| `lib/features/settings/settings_definitions.dart` | `languageSettingDef` (key, options, default) |
| `lib/core/navigation/app_router.dart` | `localeRefreshNotifier` for GoRouter |
| `lib/features/settings/pages/settings_page.dart` | Language picker tile, reset-all (delegates locale sync to `_LocaleSync`) |
| `lib/features/onboarding/pages/onboarding_page.dart` | Language button during onboarding |

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
| Postgres tables | `groups`, `group_members`, `group_invites`, `participants`, `expenses`, `expense_tags`, `telemetry`, `device_tokens` |
| RLS policies | Row-level security enforcing group membership and role-based access |
| RPC functions | `accept_invite` (auto-creates/re-links participant), `transfer_ownership`, `leave_group`, `kick_member`, `create_invite`, etc. |
| Edge Functions | `invite-redirect` (deep link redirect), `telemetry` (anonymous event collection), `send-notification` (FCM push) |
| DB triggers | `notify_group_activity` on `expenses` (INSERT/UPDATE) and `group_members` (INSERT) — sends push notifications via `pg_net` |
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

## Push Notification Architecture

Push notifications alert group members when someone else creates/edits an expense or joins the group. Uses Firebase Cloud Messaging (FCM) on all platforms (Android, iOS, Web/PWA).

### Flow

```
User A writes expense → Supabase Postgres
  ↓ AFTER trigger (notify_group_activity)
  ↓ pg_net async HTTP POST
send-notification Edge Function
  ↓ queries group_members + device_tokens (excluding actor)
  ↓ FCM HTTP v1 API
Firebase Cloud Messaging → push to User B's devices
```

### Components

| Component | File | Role |
|-----------|------|------|
| `NotificationService` | `lib/core/services/notification_service.dart` | Riverpod `keepAlive` provider — FCM init, permission request, token management, foreground/background/tap handling |
| Background handler | `lib/core/services/notification_service.dart` (top-level) | `firebaseMessagingBackgroundHandler` — required by FCM for background messages on mobile |
| Firebase init | `lib/main.dart` | `Firebase.initializeApp()` + background handler registration |
| Auth integration | `lib/app.dart` | `ref.listen(isAuthenticatedProvider)` — registers token on sign-in, unregisters on sign-out |
| Service worker | `web/firebase-messaging-sw.js` | Handles background push on web/PWA; shows notifications and handles click-to-navigate |
| Firebase SDK | `web/index.html` | Firebase compat scripts + app initialization for web |
| VAPID key | `lib/core/constants/supabase_config.dart` | `fcmVapidKey` from `--dart-define=FCM_VAPID_KEY` — required for web push token |
| DB trigger | Supabase (Migration 6) | `notify_group_activity()` on `expenses` INSERT/UPDATE and `group_members` INSERT |
| Edge function | Supabase `send-notification` | Queries recipients, builds notification, sends via FCM HTTP v1 API |
| Device tokens | Supabase `device_tokens` table | Stores FCM tokens per user/device with platform (android/ios/web) |

### Notification Events

| Event | Trigger | Message |
|-------|---------|---------|
| New expense | `expenses` INSERT | "{actor} added '{title}' ({amount})" |
| Edited expense | `expenses` UPDATE | "{actor} edited '{title}'" |
| Member joined | `group_members` INSERT | "{actor} joined the group" |

### Lifecycle

1. **App start**: Firebase initialized in `main.dart`
2. **Auth sign-in**: `app.dart` detects auth change → calls `NotificationService.initialize()` → requests permission → registers FCM token in `device_tokens`
3. **Token refresh**: FCM fires `onTokenRefresh` → token updated in `device_tokens`
4. **Auth sign-out**: `app.dart` detects auth change → calls `unregisterToken()` → deletes token from `device_tokens`
5. **Notification tap**: Extracts `group_id` from data payload → navigates to group detail via GoRouter
