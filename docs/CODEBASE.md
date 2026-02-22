# Hisab Codebase Overview

`Hisab` is a Flutter app for group expense splitting and settlement. It is offline-first: local SQLite (via the PowerSync package) is always initialized, and Supabase is optional for online auth/sync/invites/notifications.

## Stack

- Flutter + Dart
- Riverpod (`riverpod_annotation`) for state and DI
- GoRouter for navigation
- Easy Localization (`en`, `ar`, RTL support)
- PowerSync package as local SQLite engine
- Supabase (optional): Auth, Postgres, RPCs, Edge Functions
- Firebase Cloud Messaging for push notifications (Android/iOS/Web)

## Repository Layout

| Path | Purpose |
|---|---|
| `lib/` | Main Flutter application code |
| `lib/core/` | Cross-cutting services (auth, db, sync, router, notifications, telemetry, permissions, updates) |
| `lib/features/` | Feature modules (`home`, `groups`, `expenses`, `balance`, `settings`, `onboarding`) |
| `lib/domain/` | Domain entities and value types |
| `assets/translations/` | Localization JSON files |
| `web/` | PWA shell, Firebase web messaging config, redirect pages, static privacy page |
| `ios/Runner/Info.plist` | iOS permissions/deep-link/background notification config |
| `supabase/functions/invite-redirect/` | Edge Function: invite token validation and redirect |
| `supabase/functions/send-notification/` | Edge Function: FCM push (expenses, member_joined; excludes joinee) |
| `supabase/functions/telemetry/` | Edge Function: anonymous telemetry ingest |
| `docs/` | Setup and architecture documentation |
| `.github/workflows/release.yml` | CI/CD for Android builds/releases + web deploy |

## App Startup Flow

`lib/main.dart` boot sequence:

1. Flutter bindings, (web) PWA install callback, global error handlers, logging service, Easy Localization, image picker setup.
2. Settings framework (`flutter_settings_framework`) and reads persisted settings.
3. Initializes local SQLite (`PowerSyncDatabase`) unconditionally.
4. Initializes Supabase only when `SUPABASE_URL` and `SUPABASE_ANON_KEY` are provided.
5. Resolves pending OAuth flags from settings (onboarding/settings web redirect flows).
6. Initializes Firebase (for FCM) when Supabase is configured.
7. Mounts `EasyLocalization` + `ProviderScope` and injects initialized singletons.
8. Uses `_LocaleSync` as the only bridge from settings language provider to `context.setLocale`.

## Core Architecture

### Data Layer

- `lib/core/database/powersync_schema.dart` defines local schema:
  - `groups`, `group_members`, `participants`, `expenses`, `expense_tags`, `group_invites`, `invite_usages`
  - `pending_writes` queue for offline-online deferred writes
- `lib/core/repository/powersync_repository.dart` implements repositories against local SQLite + optional Supabase.
- Reads come from local DB; online mode writes target Supabase then local cache.
- In online mode while temporarily offline, some writes (notably expense writes) are queued to `pending_writes`.

### Sync Layer

`lib/core/database/database_providers.dart` contains `DataSyncService`:

- Active only when:
  - Supabase is configured
  - app is not in effective local-only mode
  - user is authenticated
- Sync actions:
  - pushes `pending_writes`
  - performs full fetch from Supabase for member groups
  - refreshes every 5 minutes while online

### Mode Model

- `local_only = true`: full local operation, no network dependency
- `local_only = false`: online mode (subject to auth/connectivity)
- `effectiveLocalOnly` also becomes true when Supabase config is missing

Switching local to online goes through sign-in and optional migration (`MigrationService`) before flipping mode.

## Navigation and Deep Links

- Router: `lib/core/navigation/app_router.dart`
  - onboarding redirect guard
  - shell route for home/settings tabs
  - group/invite/expense routes
- Deep link handling: `lib/core/navigation/invite_link_handler.dart`
  - reads initial and streamed app links
  - persists pending invite token in settings to survive onboarding/OAuth redirects
  - navigates to invite accept route when appropriate

## Localization and RTL

- Source of truth for language is settings key `language`.
- `_LocaleSync` (in `main.dart`) updates Easy Localization locale when provider changes.
- `App` (`lib/app.dart`) intentionally reads locale from `context.locale` only.
- Router refreshes on locale changes via `localeRefreshNotifier`.
- Supported locales: English (`en`), Arabic (`ar`).

## Authentication

`lib/core/auth/auth_service.dart` supports:

- email/password sign-in and sign-up
- magic link sign-in
- Google and GitHub OAuth
- profile metadata update (`full_name`, `avatar_id`)
- resend confirmation

Redirect behavior:

- Web uses `SITE_URL` if provided.
- Native uses deep link callback `io.supabase.hisab://callback`.

## Notifications (FCM)

Push notifications are sent when expenses are added/edited or members join a group. The pipeline is: **Supabase (trigger) → pg_net → send-notification Edge Function → Firebase Cloud Messaging → Flutter**. Full setup and verification are in [SUPABASE_SETUP.md](SUPABASE_SETUP.md) (Section 5: send-notification, “Push notifications: end-to-end flow and verification”, and Section 9: “Push notifications not received”).

**Flutter** (`lib/core/services/notification_service.dart`):

- Requests notification permission; registers/unregisters FCM token in Supabase `device_tokens` (upsert on `user_id,token`), including the current app `locale` for language-aware notifications.
- Handles token refresh, foreground display (mobile: local notifications), and tap → navigate to group detail using `message.data['group_id']`.
- Expects incoming messages to have `notification` (title, body) and `data.group_id` (string).

**Backend:** Database trigger `notify_on_expense_change` (and `notify_on_member_join`) calls `notify_group_activity()`, which POSTs to the `send-notification` Edge Function with `group_id`, `actor_user_id`, `action`, and optional expense fields. The Edge Function (`supabase/functions/send-notification/index.ts`) loads other group members’ tokens and `locale` from `device_tokens` and sends FCM v1 messages (one per token). For `member_joined`, the actor is the new member; the Edge Function excludes the actor so the joinee does not receive a push notification. Notification title and body are localized per device using the stored `locale` (en/ar; fallback en).

**Web:** `web/index.html` initializes Firebase web SDK; `web/firebase-messaging-sw.js` handles background push and clicks. Web token registration requires `FCM_VAPID_KEY` at build time.

**Settings:** `notifications_enabled` controls initialization and token registration; the toggle is shown only in online mode.

## Feature Modules

- `features/home`: groups list and manual refresh trigger
- `features/groups`: create/detail/settings, invite management, invite acceptance
- `features/expenses`: create/edit/detail expenses, split logic UI, receipt input hooks
- `features/balance`: settlement list and record settlement flow
- `features/settings`:
  - account mode and auth controls
  - theme/language/font/favorite currencies
  - local-only toggle + migration
  - import/export backup JSON
  - telemetry + notifications toggles
  - logs viewer/clear/report flow
  - feedback capture integration
  - About: version row tappable to check for updates manually
- `features/onboarding`: two-page onboarding with mode selection and auth gate for online mode

## Settings Framework

Definitions live in `lib/features/settings/settings_definitions.dart`.

Major persisted keys include:

- appearance: `theme_mode`, `theme_color`, `language`, `font_size_scale`, `favorite_currencies`
- mode/lifecycle: `local_only`, `onboarding_completed`, pending OAuth flags, pending invite token
- privacy: `telemetry_enabled`, `notifications_enabled`
- receipt AI: OCR/AI flags, provider, and API keys

## Web and PWA

- PWA manifest: `web/manifest.json`
- Install prompt integration: `pwa_install` package + `PwaInstallBanner` widget
- Invite links use the web app domain (e.g. hisab.shenepoy.com) when `INVITE_BASE_URL` is set. The route `/functions/v1/invite-redirect` is handled by the Flutter web app, which redirects to the Supabase Edge Function so the token is validated and the user is sent to `redirect.html`.
- Invite redirect static page: `web/redirect.html`
  - desktop -> web invite route
  - mobile -> attempts app deep link with timed web fallback
- Public privacy page: `web/privacy/index.html`

## Supabase Backend Contract

This repo is the **source of truth** for all Supabase Edge Functions. See [EDGE_FUNCTIONS.md](EDGE_FUNCTIONS.md) for the list and deploy commands.

- `supabase/functions/invite-redirect/index.ts` — validates invite token and redirects to `redirect.html`
- `supabase/functions/send-notification/index.ts` — sends FCM push notifications (expenses, member_joined; excludes joinee)
- `supabase/functions/telemetry/index.ts` — accepts anonymous usage telemetry events

The app also depends on Supabase-side schema, RLS, and RPCs documented in `docs/SUPABASE_SETUP.md`, including:

- tables such as `groups`, `group_members`, `participants`, `expenses`, `expense_tags`, `group_invites`, `invite_usages`, `telemetry`, `device_tokens`
- RPCs such as `accept_invite`, `transfer_ownership`, `leave_group`, `kick_member`, `update_member_role`, `create_invite`, etc.

Schema and security/performance can be re-verified via [Supabase MCP](https://supabase.com/docs/guides/getting-started/mcp) (`list_tables`, `get_advisors`).

## MCP available in the IDE

The following MCP (Model Context Protocol) servers are enabled in this project. Use them for schema checks, Dart/Flutter tooling, browser automation, and Firebase operations.

| Server | Purpose |
|--------|--------|
| **Supabase** (`plugin-supabase-supabase`) | Database and project management: `list_tables`, `get_advisors` (security/performance), `execute_sql`, `apply_migration`, `list_migrations`, `list_extensions`, branch ops (`create_branch`, `merge_branch`, etc.), Edge Functions (`list_edge_functions`, `deploy_edge_function`, `get_edge_function`), `generate_typescript_types`, `get_logs`, project/org (`list_projects`, `get_project`, `list_organizations`), `search_docs`, and project lifecycle (`pause_project`, `restore_project`, etc.). |
| **Dart** (`user-dart`) | Dart/Flutter development: prefer over running tools in a shell. Includes `analyze_files`, `run_tests`, `dart_format`, `dart_fix`, `pub`, `pub_dev_search`, `create_project`; running apps (`launch_app`, `stop_app`, `hot_reload`, `hot_restart`), `list_devices`, `list_running_apps`, `get_app_logs`, `get_runtime_errors`; widget inspector (`get_widget_tree`, `get_selected_widget`, `set_widget_selection_mode`); and daemon/symbols (`connect_dart_tooling_daemon`, `resolve_workspace_symbol`, `hover`, `signature_help`). |
| **cursor-ide-browser** | Web automation and testing: navigate, lock/unlock tab, snapshot page, click/type/scroll/drag, handle dialogs; `browser_tabs`, `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests`, `browser_profile_start`/`browser_profile_stop` (CPU profiling). Lock before interactions; unlock when done. |
| **Firebase** (`project-0-hisab-firebase`) | Firebase project (FCM, Hosting, etc.): developer knowledge docs, Realtime Database get/set, Remote Config, Auth (users, SMS policy), Messaging send, plus prompts/resources for init, deploy, rules, Crashlytics, etc. |
| **Supabase Author** (`plugin-supabase-author`) | Authoring/editorial support for Supabase-related content. |

Tool descriptors (names and parameters) live under `.cursor/projects/.../mcps/<server>/tools/*.json`. Check each tool’s schema before calling.

## Configuration

Build-time config is via `--dart-define` in `lib/core/constants/supabase_config.dart`:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `INVITE_BASE_URL` (optional)
- `SITE_URL` (optional auth email redirect)
- `FCM_VAPID_KEY` (web push)

If Supabase defines are missing, app runs local-only by design.

## Platform Permissions

Runtime permission handling is centralized in `lib/core/services/permission_service.dart`:

- camera
- photo library
- notifications

iOS declarations are present in `ios/Runner/Info.plist`, including:

- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSUserNotificationsUsageDescription`
- `UIBackgroundModes: remote-notification`
- custom URL scheme `io.supabase.hisab`

## CI/CD

`.github/workflows/release.yml`:

- triggers on tags `v*` or manual dispatch
- builds Android APK + AAB
- creates GitHub release (tag flow)
- optional Play Store internal deploy
- builds/deploys Flutter web to Firebase Hosting (copies privacy page to build output)

## Key Dependencies (Selected)

- state: `flutter_riverpod`, `riverpod_annotation`
- navigation: `go_router`
- local db/sync engine: `powersync`
- backend/auth: `supabase_flutter`
- notifications: `firebase_core`, `firebase_messaging`, `flutter_local_notifications`
- localization: `easy_localization`
- settings framework: `flutter_settings_framework`
- connectivity: `connectivity_plus`
- permissions: `permission_handler`
- feedback: `feedback`
- backup/file ops: `file_picker`

## Related Docs

- `docs/SUPABASE_SETUP.md` - complete backend bootstrap and SQL/RPC policy setup
- `docs/CONFIGURATION.md` - runtime configuration quick reference
- `docs/RELEASE_SETUP.md` and `docs/PLAY_CONSOLE_DECLARATIONS.md` - release/distribution notes
