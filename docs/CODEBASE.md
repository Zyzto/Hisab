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
| `supabase/functions/invite-redirect/` | Edge Function source for invite redirect |
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

Implemented in `lib/core/services/notification_service.dart`:

- requests notification permission
- registers/unregisters device token in Supabase `device_tokens`
- handles token refresh
- handles foreground display (mobile local notifications)
- handles tap navigation to group details

Web-specific pieces:

- `web/index.html` initializes Firebase web SDK and listens for service worker click messages
- `web/firebase-messaging-sw.js` handles background push and notification clicks

Settings integration:

- `notifications_enabled` controls initialization/token registration.
- Toggle only appears in online mode.

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
- Invite redirect static page: `web/redirect.html`
  - desktop -> web invite route
  - mobile -> attempts app deep link with timed web fallback
- Public privacy page: `web/privacy/index.html`

## Supabase Backend Contract

This repo contains one Edge Function source: `supabase/functions/invite-redirect/index.ts`.

The app also depends on Supabase-side schema, RLS, RPCs, and additional edge functions documented in `docs/SUPABASE_SETUP.md`, including:

- tables such as `groups`, `group_members`, `participants`, `expenses`, `expense_tags`, `group_invites`, `invite_usages`, `telemetry`, `device_tokens`
- RPCs such as `accept_invite`, `transfer_ownership`, `leave_group`, `kick_member`, `update_member_role`, `create_invite`, etc.
- optional edge functions `telemetry` and `send-notification` (documented, not committed in this repo snapshot)

Schema and security/performance can be re-verified via [Supabase MCP](https://supabase.com/docs/guides/getting-started/mcp) (`list_tables`, `get_advisors`).

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
