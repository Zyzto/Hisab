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
| `lib/core/` | Cross-cutting: auth, constants, database, debug, navigation, receipt, repository, services, telemetry, theme, update, utils, widgets |
| `lib/features/` | Feature modules (`home`, `groups`, `expenses`, `balance`, `settings`, `onboarding`) |
| `lib/domain/` | Domain entities and value types; barrel export in `domain.dart` |
| `assets/translations/` | Localization JSON files |
| `web/` | PWA shell, Firebase web messaging config, redirect pages, static privacy page |
| `ios/Runner/Info.plist` | iOS permissions/deep-link/background notification config |
| `supabase/functions/invite-redirect/` | Edge Function: invite token validation and redirect |
| `supabase/functions/og-invite-image/` | Edge Function: GET `?token=...` → 1200×630 PNG (QR, branding) for invite previews |
| `supabase/functions/send-notification/` | Edge Function: FCM push (expenses, member_joined; excludes joinee) |
| `supabase/functions/telemetry/` | Edge Function: anonymous telemetry ingest |
| `docs/` | Setup and architecture documentation |
| `test/` | Tests mirroring `lib/` layout; see [test/README.md](test/README.md) |
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
  - `local_archived_groups` — per-user “hide from my list” (not synced)
  - `pending_writes` queue for offline-online deferred writes
- **Repositories** (`lib/core/repository/`): `group_repository`, `participant_repository`, `expense_repository`, `group_member_repository`, `group_invite_repository`, `tag_repository`, `powersync_repository`. Wired in `repository_providers.dart` with `effectiveLocalOnlyProvider` and connectivity; implementations in `powersync_repository.dart` and per-entity repositories.
- Reads come from local DB; online mode writes target Supabase then local cache.
- In online mode while temporarily offline, some writes (notably expense writes) are queued to `pending_writes`.

### Domain

`lib/domain/domain.dart` is the barrel export. Main entities: `group`, `group_member`, `group_invite`, `invite_usage`, `group_role`, `participant`, `expense`, `expense_tag`, `receipt_line_item`, `split_type`, `transaction_type`, `settlement_transaction`, `settlement_item`, `settlement_method`, `settlement_snapshot`, `participant_balance`, `group_balance_result`, `delete_my_data_preview`.

### Sync Layer

- **SyncEngine** (`lib/core/database/sync_engine.dart`): testable full fetch from Supabase into local DB and push of `pending_writes`; **SyncBackend** (`lib/core/database/sync_backend.dart`) abstracts the backend for tests.
- **DataSyncService** (`lib/core/database/database_providers.dart`) uses SyncEngine and is active only when:
  - Supabase is configured
  - app is not in effective local-only mode
  - user is authenticated
- Sync actions: pushes `pending_writes`, performs full fetch for member groups, refreshes every 5 minutes while online.

### Mode Model

- `local_only = true`: full local operation, no network dependency
- `local_only = false`: online mode (subject to auth/connectivity)
- `effectiveLocalOnly` also becomes true when Supabase config is missing

Switching local to online goes through sign-in and optional migration (`MigrationService`) before flipping mode.

### Core services

Key services: `lib/core/services/` — **notification_service** (FCM token, foreground display, tap → group; web impl in `notification_service_web_impl.dart`), **connectivity_service**, **permission_service** (camera, photos, notifications), **migration_service** (local → online), **settle_up_service** (settlement logic), **delete_my_data_service** (delete flow), **http_fetch_helper** (shared HTTP fetch), **firebase_status_client** / **status_page_client** (status/health), **github_user_client** (About me), **exchange_rate_service**; `lib/core/telemetry/` — **telemetry_service**.

### Core widgets

Shared widgets in `lib/core/widgets/`: **AsyncValueBuilder**, **BackButtonKeyboardDismiss**, **ConnectionBanner**, **CurrencyPickerList**, **ErrorContentWidget**, **ExpandableSection**, **FloatingNavBar**, **PwaInstallBanner**, **ServicesStatusSheet**, **SyncStatusChip** (`sync_status_icon.dart`), **Toast**.

### Receipt (core/receipt)

Receipt storage (`receipt_storage`, `receipt_storage_upload` with io/stub), **scan** (`receipt_scan_service`), **LLM** (`receipt_llm_service`), **image view** (`receipt_image_view`), **providers** (`receipt_providers`). Used by expense form and settings (Receipt AI). Platform-specific impls in `*_io.dart` / `*_stub.dart`.

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

**Backend:** Database trigger `notify_on_expense_change` (and `notify_on_member_join`) calls `notify_group_activity()`, which POSTs to the `send-notification` Edge Function with `group_id`, `actor_user_id`, `action`, and optional expense fields. The Edge Function (`supabase/functions/send-notification/index.ts`) loads other group members’ tokens and `locale` from `device_tokens` and sends FCM v1 messages (one per token). For **expense_created** and **expense_updated**, the actor is the user who created or last updated the expense; the Edge Function excludes that actor so only **other** group members receive the push. For `member_joined`, the actor is the new member; the Edge Function excludes the actor so the joinee does not receive a push notification. Notification title and body are localized per device using the stored `locale` (en/ar; fallback en).

**Web:** `web/index.html` initializes Firebase web SDK; `web/firebase-messaging-sw.js` handles background push and clicks. Web token registration requires `FCM_VAPID_KEY` at build time.

**Settings:** `notifications_enabled` controls initialization and token registration; the toggle is shown only in online mode.

## Feature Modules

- `features/home`: groups list (Personal and Groups sections) via **home_list_provider** (ordered list, pinned/custom order), **routes**, create FAB + modal (Create group / Create personal), manual refresh trigger
- `features/groups`: create/detail/settings (including personal vs group branches and convert flows), invite management, invite acceptance; **invite_redirect_proxy** (and _web, _stub, _page) for web/invite redirect; **create_invite_sheet** (invite creation UI)
- `features/expenses`: create/edit/detail expenses (**expense_detail_shell**), split logic UI, receipt input hooks; **expense_navigation_direction** (provider), **expense_form_constants**, **category_icons**
- `features/balance`: settlement list and record settlement flow
- `features/settings`:
  - account mode and auth controls; **edit_profile_sheet**
  - theme/language/font/favorite currencies
  - local-only toggle + migration
  - import/export backup JSON (**backup_helper**: `parseBackupJson`, etc.)
  - telemetry + notifications toggles
  - logs viewer/clear/report flow
  - feedback capture (**feedback_upload**, feedback_clipboard with io/stub)
  - About: version row tappable to check for updates manually; About me shows developer info from GitHub (avatar, name, bio, profile link)
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
- PowerSync workers: `web/powersync_db.worker.js`, `web/powersync_sync.worker.js`
- Install prompt integration: `pwa_install` package + `PwaInstallBanner` widget
- Invite links use the web app domain (e.g. hisab.shenepoy.com) when `INVITE_BASE_URL` is set. On deploy, the route `/functions/v1/invite-redirect` is served by **Firebase Hosting** via a rewrite to static `invite-redirect.html` (built from `web/invite-redirect-template.html`); that page redirects to the Supabase Edge Function, which validates the token and redirects the user to `redirect.html`. This works on the Firebase free (Spark) plan with no Cloud Function. When the user is already inside the web app, the same path is handled by the Flutter app (GoRouter), which redirects to the Supabase Edge Function.
- Invite redirect static page: `web/redirect.html`
  - desktop -> web invite route
  - mobile -> attempts app deep link with timed web fallback
- Invite/OG assets: `web/invite-redirect-template.html`, `web/og-invite.png` (used in invite link and OG image flow; see [EDGE_FUNCTIONS.md](EDGE_FUNCTIONS.md)).
- Public privacy page: `web/privacy/index.html`
- Account deletion is described in `docs/DELETE_ACCOUNT.md`; the in-app options are Delete local data and Delete cloud data under Settings > Advanced (and a public page at `web/delete-account/index.html` when deployed).

## Supabase Backend Contract

This repo is the **source of truth** for all Supabase Edge Functions. See [EDGE_FUNCTIONS.md](EDGE_FUNCTIONS.md) for the list and deploy commands.

- `supabase/functions/invite-redirect/index.ts` — validates invite token and redirects to `redirect.html`
- `supabase/functions/og-invite-image/` — GET `?token=...` returns 1200×630 PNG (QR code, branding) for invite link previews; deploy with `--no-verify-jwt`
- `supabase/functions/send-notification/index.ts` — sends FCM push notifications (expenses, member_joined; excludes joinee)
- `supabase/functions/telemetry/index.ts` — accepts anonymous usage telemetry events

On the free plan, invite redirect uses only static Hosting files (`invite-redirect.html` + `redirect.html`). A **Firebase Cloud Function** can optionally serve the same path with dynamic OG meta for crawlers (see [EDGE_FUNCTIONS.md](EDGE_FUNCTIONS.md) for `functions/` and hosting rewrites).

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
| **Supabase Author** (`plugin-supabase-author`, if enabled) | Authoring/editorial support for Supabase-related content. |

Tool descriptors (names and parameters) live under `.cursor/projects/.../mcps/<server>/tools/*.json`. Check each tool’s schema before calling.

### Example: cross-MCP workflow (Supabase → Firebase)

A typical flow using both Supabase and Firebase MCP:

1. **Find a user in Supabase**  
   Use Supabase MCP `execute_sql` with `project_id` from `list_projects`. Example: look up by name in `auth.users` (`raw_user_meta_data->>'full_name'`) or in `public.participants` (`name`, `user_id`). Use the returned `user_id` (UUID) for the next step.

2. **Get the user’s FCM token**  
   Query `public.device_tokens` with that `user_id` to get `token` and `platform` (e.g. `android`, `ios`, `web`). The `token` is the FCM registration token needed for sending a push.

3. **Send a push via Firebase MCP**  
   Call Firebase MCP tool `messaging_send_message` with:
   - `registration_token`: the token from step 2  
   - `title`: notification title (e.g. app name)  
   - `body`: notification body text  

   The Firebase server may appear as `project-0-hisab-firebase` in Cursor (not `firebase`). If a tool call fails with “MCP server does not exist: firebase”, use the server name listed in the error under “Available servers”.

### How to use Supabase MCP

The Supabase MCP server (`plugin-supabase-supabase`) talks to your linked Supabase project. Use it from the IDE (e.g. Cursor) so the AI or you can run schema checks, apply migrations, and run SQL without leaving the editor.

1. **Get the project ID**  
   Call `list_projects` (no arguments). Use the `id` of the project you care about (e.g. **Hisab_01**) as `project_id` for all other Supabase MCP tools.

2. **Common operations**
   - **Schema:** `list_tables` — `project_id`, `schemas` (default `["public"]`). Returns tables, columns, RLS, row counts, and FKs.
   - **Migrations:** `list_migrations` — `project_id`. Shows applied migrations.  
   - **Apply a migration:** `apply_migration` — `project_id`, `name` (snake_case, e.g. `participants_left_at_and_rejoin_reuse`), `query` (full SQL string). Use the contents of a file under `supabase/migrations/*.sql` for `query`; do not hardcode generated IDs in data migrations.
   - **Run SQL:** `execute_sql` — `project_id`, `query`. For one-off or read-only checks.
   - **Advisors:** `get_advisors` — `project_id`. Security and performance suggestions for the project.

3. **Tool schemas**  
   Before calling a tool, read its descriptor under `.cursor/projects/<workspace>/mcps/plugin-supabase-supabase/tools/<tool_name>.json` to see required and optional arguments and types.

4. **Docs**  
   [Supabase MCP guide](https://supabase.com/docs/guides/getting-started/mcp) — setup and overview.

### How to use Firebase MCP

The Firebase MCP server is configured in `.cursor/mcp.json` as `firebase` (command: `npx -y firebase-tools@latest mcp`). When Cursor loads it for this project, the **server identifier** may be `project-0-hisab-firebase` — use that name when calling Firebase MCP tools (e.g. from the AI or from scripts that invoke MCP).

1. **Auth and project**  
   Many tools require the user to be signed in (`npx firebase-tools login`) and a Firebase project to be set. The server uses the same credentials as the Firebase CLI in the environment where Cursor runs.

2. **Sending a push notification**  
   Use the `messaging_send_message` tool with:
   - `registration_token`: FCM device token (from app registration, or from Supabase `device_tokens.token` for a user)
   - `title` (optional): notification title  
   - `body` (optional): notification body  
   Supply either `registration_token` or `topic`, not both. See the tool descriptor under `mcps/<firebase-server>/tools/` for the full schema.

3. **Other capabilities**  
   The Firebase MCP also exposes tools for Firestore, Auth, Remote Config, Crashlytics, Realtime Database, Hosting, and prompts/resources for init and deploy. Check the tool list in the server’s `tools/` folder.

## Configuration

Build-time config is via `--dart-define` in `lib/core/constants/supabase_config.dart`:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `INVITE_BASE_URL` (optional)
- `SITE_URL` (optional auth email redirect)
- `FCM_VAPID_KEY` (web push)

Secrets template: `lib/core/constants/app_secrets_example.dart`; see `docs/CONFIGURATION.md` for runtime configuration. If Supabase defines are missing, app runs local-only by design.

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

## Testing

- **Run all tests:** `flutter test`
- **Coverage:**
  - **Unit:** domain, settle-up, sync error classification, backup parse, translations.
  - **Widget:** Public custom widgets under `test/` mirroring `lib/`: `test/core/` (async_value_builder, back_button_keyboard_dismiss, connection_banner, currency_picker_list, expandable_section, floating_nav_bar, invite_link_handler, pwa_install_banner, sync_status_chip), `test/groups/` (group_card, create_invite_sheet), `test/expenses/` (expense_list_tile, expense_title_section, expense_amount_section, expense_split_section, expense_bill_breakdown_section, expense_detail_body, expense_detail_body_header), `test/settings/` (logs_viewer_dialog, privacy_policy_page), `test/pages/` (main_scaffold, home_page, archived_groups_page), `test/balance/` (balance_list), `test/onboarding/` (onboarding_page), plus error_content and app. Widget tests use EasyLocalization + MaterialApp; Riverpod widgets use ProviderScope with overrides when needed. See [test/widget_test_helpers.dart](test/widget_test_helpers.dart) and [test/README.md](test/README.md).
  - **Locale:** Key widgets are tested in both English and Arabic via `test/widget_test_helpers.dart`: `pumpApp(tester, child: ..., locale: Locale('ar'))` and `testSupportedLocales`. Edge cases (empty/zero/long content, optional params) are covered where relevant.
  - **Integration-style:** Local PowerSync DB, sync engine with fake backend. See [test/README.md](test/README.md) for PowerSync native binary requirements and coverage (`flutter test --coverage`).
- **Widget test helper:** `test/widget_test_helpers.dart` provides `pumpApp(tester, child, locale?, pumpAndSettle?)` to wrap the widget in EasyLocalization + MaterialApp; use for presentational widgets. For widgets that depend on Riverpod, build ProviderScope + EasyLocalization + MaterialApp inline with overrides (see e.g. `test/balance/balance_list_widget_test.dart`).
- **Generated code:** Run `dart run build_runner build` (or `watch`) to regenerate `.g.dart` files before running tests or when changing providers/settings.

## Development

- **Codegen:** Use `dart run build_runner build` after changing Riverpod providers, settings, or other annotated code so `.g.dart` files stay in sync.
- **Tooling:** Prefer the Dart and Supabase MCP servers (see “MCP available in the IDE” above) for analysis, format, schema checks, and migrations instead of running CLI tools manually.

## Recent improvements (documented changes)

The following improvements are reflected in the codebase and docs:

- **Sync:** DataSyncService retries sync on transient errors (up to 3 attempts with backoff). Auth errors (401/403) do not retry and set a “sync failed” UI status. See `lib/core/database/sync_errors.dart` and `SyncStatus.syncFailed` in `lib/core/services/connectivity_service.dart`.
- **Error UX:** Default async error title is localized (`generic_error`). Shared `ErrorContentWidget` (with optional retry) is used for error states in balance, group detail, invite accept/management, archived groups, expense form, and group settings. See `lib/core/widgets/error_content.dart`.
- **Backup import:** `parseBackupJson()` returns `BackupParseResult` with `data` and `errorMessageKey` so the settings import UI can show specific messages (invalid format, unsupported version, or parse failure). See `lib/features/settings/backup_helper.dart`.
- **Accessibility:** Semantics/semanticsLabel added for main actions (create group, scan invite, archived, open group, add expense/participant, record settlement) and for the sync status chip. See home, group card, group detail, balance list, sync_status_icon.
- **Tests:** Unit tests (sync errors, backup parse, domain, settle-up, translations). Widget tests cover public custom widgets (core, groups, expenses, settings, pages) with a shared helper `pumpApp()` and locale/edge-case coverage (en/ar, empty/zero/long). See `test/widget_test_helpers.dart` and `test/README.md`. CODEBASE “Testing” and “Development” sections describe how to run tests and use build_runner/MCP.
- **Config/docs:** Receipt AI API keys documented as user-provided and device-only in `docs/CONFIGURATION.md`. Custom `ErrorWidget.builder` in `main.dart` for framework build errors.
- **Expense split UX:** In the expense form, when split type is **Parts**, each participant row has minus/plus buttons to adjust the part value (0–999) without typing. **Amounts** and **Parts** rows use a single field per participant (the separate “formatted amount” column was removed); the “Total: X / Y” line remains for amounts validation. See `lib/features/expenses/widgets/expense_split_section.dart`.
- **Amounts split: preserve manual amounts:** When editing one participant’s amount then another’s, the first value is no longer overwritten. The form tracks which participants the user has manually edited (`_amountsManuallySetIds`); redistribution only updates participants not in that set. The set is cleared when the expense total changes, when a participant is excluded, or when split type changes. See `lib/features/expenses/pages/expense_form_page.dart` (`_applyAmountsChange`, `_amountsManuallySetIds`, `_lastAmountCentsForAmounts`).
- **Amounts split: 0.01 rounding fix:** Equal splits and redistribution use integer cents so the sum of displayed amounts equals the expense total exactly (e.g. 500 among 3 shows 166.67, 166.67, 166.66). Applied in `_ensureCustomSplitValues` (amounts branch) and `_applyAmountsChange` (equal and proportional branches); helper `_formatCentsAsAmount` formats cents for display.
- **Amounts split: fill on blur:** If an amount field is 0 or empty and the user leaves the field (blur), it is auto-filled with the remainder (total minus the sum of the other participants’ amounts) so the total matches. No redistribution; only that field is updated. Implemented via a focus-node listener in the expense form; see `_handleAmountFieldUnfocused` in `lib/features/expenses/pages/expense_form_page.dart`.
- **Personal (my-expenses-only) feature:** Groups can be created or converted to “personal” mode: single participant, optional budget, minimal UI (no Balance/People tabs, no split or invite). Create via FAB modal (Create group / Create personal); convert in settings (Share as group / Use as personal; group→personal revokes invites). Data: `Group.isPersonal`, `Group.budgetAmountCents`; schema and sync include both; backup/restore and i18n covered. See `docs/PERSONAL_FEATURE.md`.
- **Back button dismisses keyboard:** When the keyboard is visible, the first back press (Android) only closes the keyboard and does not navigate. Implemented app-wide via `BackButtonKeyboardDismiss` in `lib/core/widgets/back_button_keyboard_dismiss.dart`, registered in the router builder so it runs before route-specific back handling.
- **Anonymize participant name on account deletion only:** When a user's auth account is deleted (e.g. after an account deletion request), a database trigger runs and replaces their participant display name in all groups with a random placeholder (e.g. "Former member a3f2b1") and clears avatar, so expense history shows a neutral label. Leave/kick/archive do not change names. See migration `20250226000000_anonymize_only_on_account_delete.sql` (trigger on `auth.users` DELETE).
- **Upgrader logging:** Debug logging from the upgrader package is disabled. The app logs one aggregated line per update check (manual from Settings > About and automatic via UpgradeAlert) via the logging service. See `lib/app.dart` (`debugLogging: false`, `willDisplayUpgrade`, and the manual-check callback).
- **CODEBASE doc:** This overview was updated to reflect current lib layout (core subdirs, domain barrel, repositories), SyncEngine/SyncBackend, core services/widgets/receipt, feature details, Edge Functions (including og-invite-image), web assets, and test layout.

## Related Docs

- `docs/SUPABASE_SETUP.md` - complete backend bootstrap and SQL/RPC policy setup
- `docs/SUPABASE_BACKUP.md` - how to backup Supabase database (dashboard, pg_dump, script)
- `docs/EDGE_FUNCTIONS.md` - Supabase Edge Functions list and deploy commands (invite-redirect, og-invite-image, send-notification, telemetry)
- `docs/PERSONAL_FEATURE.md` - personal (my-expenses-only) mode: data model, flows, code locations, backup, i18n
- `docs/CONFIGURATION.md` - runtime configuration quick reference
- `docs/RELEASE_SETUP.md` and `docs/PLAY_CONSOLE_DECLARATIONS.md` - release/distribution notes
- `docs/DELETE_ACCOUNT.md` - user-facing guide for deleting data and requesting account deletion
