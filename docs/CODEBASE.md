# Codebase overview

<!-- markdownlint-disable MD060 -->

Hisab is a Flutter app for group expense splitting and settlement. Local SQLite (PowerSync package) always starts; Supabase is optional for auth, sync, invites, and push.

Product and install overview: [../README.md](../README.md). Doc index: [README.md](README.md).

## Stack

- Flutter + Dart
- Riverpod (`riverpod_annotation`) for state and DI
- GoRouter for navigation
- Easy Localization (`en`, `ar`, RTL support)
- PowerSync package as local SQLite engine
- Supabase (optional): Auth, Postgres, RPCs, Edge Functions
- Firebase Cloud Messaging for push notifications (Android/iOS/Web)

**Platform support:** Run/build/release targets are Android, iOS, and web. Linux is **not** supported as an app target (no launch option, no `flutter build linux`, no Linux release). On a Linux host you can still use test tooling: `flutter test`, integration tests (e.g. `flutter drive -d web-server` or with another device), and CI runs unit/widget/integration tests on `ubuntu-latest`.

## Repository Layout

| Path | Purpose |
|---|---|
| `lib/` | Main Flutter application code |
| `lib/core/` | Cross-cutting: auth, constants, database, debug, layout, motion, navigation, pwa, receipt, repository, services, telemetry, theme, update, utils, widgets |
| `lib/features/` | Feature modules (`home`, `profile`, `groups`, `expenses`, `balance`, `settings`, `onboarding`, `transaction_scanner`) |
| `lib/domain/` | Domain entities and value types; barrel export in `domain.dart` |
| `assets/translations/` | Localization JSON files |
| `web/` | PWA shell, Firebase web messaging config, redirect pages, static privacy page |
| `ios/Runner/Info.plist` | iOS permissions/deep-link/background notification config |
| `supabase/functions/invite-redirect/` | Edge Function: invite token validation and redirect |
| `supabase/functions/og-invite-image/` | Edge Function: GET `?token=...` → 1200×630 PNG (QR, branding) for invite previews |
| `supabase/functions/send-notification/` | Edge Function: `user_notifications` + FCM push (expense create/update/delete, member_joined; excludes actor) |
| `supabase/functions/telemetry/` | Edge Function: anonymous telemetry ingest |
| `docs/` | Setup and architecture documentation; see [docs/README.md](README.md) for an index |
| `test/` | Tests mirroring `lib/` layout; see [test/README.md](../test/README.md) |
| `integration_test/` | Full-app integration tests (local-only + online); see [test/README.md](../test/README.md) |
| `supabase/` | Local Supabase config, migrations, seed data for online integration tests |
| `scripts/` | Helper scripts (`run_online_tests.sh` for online tests) |
| `.github/workflows/release.yml` | CI/CD for Android builds/releases + web deploy + online integration tests |

## App Startup Flow

`lib/main.dart` boot sequence:

1. Flutter bindings, global error handlers, logging service, Easy Localization, image picker setup. On web, `web/index.html` exposes `window.hisabPwa` (install + capability detection) and shows a boot splash until Flutter mounts.
2. Settings framework (`flutter_settings_framework`) and reads persisted settings.
3. Initializes local SQLite (`PowerSyncDatabase`) unconditionally.
4. Initializes Supabase only when `SUPABASE_URL` and `SUPABASE_ANON_KEY` are provided. On web, `_finalizeWebOAuthReturn` cleans auth callback URL params and retries session recovery once if the stock path left no session.
5. Resolves pending OAuth flags from settings (onboarding/settings web redirect flows).
6. Initializes Firebase (for FCM) when Supabase is configured.
7. Mounts `EasyLocalization` + `ProviderScope` and injects initialized singletons. `App` surfaces any pending web OAuth error toast after the navigator is ready.
8. Uses `_LocaleSync` as the only bridge from settings language provider to `context.setLocale`.

## Core Architecture

### Data Layer

- `lib/core/database/powersync_schema.dart` defines local schema:
  - `groups`, `group_members`, `participants`, `expenses`, `expense_tags`, `group_invites`, `invite_usages`, `user_notifications`
  - `local_archived_groups` — per-user “hide from my list” (not synced)
  - `draft_transactions`, `scanner_sender_rules`, `scanner_patterns` — Transaction Scanner (local-only; not synced); see [TRANSACTION_SCANNER.md](TRANSACTION_SCANNER.md)
  - `pending_writes` queue for offline-online deferred writes
- **PowerSync `id` column:** PowerSync adds an `id` column automatically to each table. Do not add `Column.text('id')` (or any custom `id` column) in the schema — it will trigger: *"id column is automatically added, custom id columns are not supported"*. Hisab uses PowerSync 2.x as the **local SQLite engine** with a custom `SyncEngine` (not PowerSync Cloud Sync Streams).
- **Repositories** (`lib/core/repository/`): `group_repository`, `participant_repository`, `expense_repository`, `group_member_repository`, `group_invite_repository`, `tag_repository`, `user_notification_repository`, `powersync_repository`. Wired in `repository_providers.dart` / profile providers with `effectiveLocalOnlyProvider` and connectivity; implementations in `powersync_repository.dart` and per-entity repositories.
- Reads come from local DB; online mode writes target Supabase then local cache.
- In online mode while temporarily offline, some writes (notably expense writes) are queued to `pending_writes`.
- **Expense exchange rate:** Each expense stores `exchange_rate` and `base_amount_cents` (group-currency amount). Display and settle-up **always** use these stored values so amounts stay consistent over time and when editing; do not recalculate from a live API for existing expenses.

**Schema alignment:** The source of truth for synced table columns is the INSERT column list in `lib/core/database/sync_engine.dart`. When adding or changing columns in Supabase (or in the local schema), keep all three in sync: (1) Supabase table definition (migrations), (2) `lib/core/database/powersync_schema.dart`, and (3) the corresponding INSERT in `sync_engine.dart`. PowerSync adds an `id` column automatically to each table — do not add a custom `Column.text('id')` in the schema (it will trigger an assertion). The test in `test/schema_alignment_test.dart` covers all eight synced tables (including user-scoped `user_notifications`).

### Domain

`lib/domain/domain.dart` is the barrel export. Main entities: `group`, `group_member`, `group_invite`, `invite_usage`, `group_role`, `participant`, `expense`, `expense_tag`, `receipt_line_item`, `split_type`, `transaction_type`, `settlement_transaction`, `settlement_item`, `settlement_method`, `settlement_snapshot`, `participant_balance`, `group_balance_result`, `delete_my_data_preview`, `user_notification`.

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

### Error reports (Share / GitHub)

- **`lib/core/utils/error_report_helper.dart`** — `buildErrorReportPayload`, `shareErrorReport`, `openErrorReportGitHubIssue`. Report **markdown** uses English section headings and includes **environment** (app version, platform, UI + device locale), **recent navigation** from `NavigationTrace`, optional **Summary (English)** (e.g. same string as `Log.warning` in `run_guarded_async`), **user-visible message** (may be localized), **technical details**, and **stack trace**. `readUiLocaleTagForReport` reads Easy Localization’s locale when present.
- **`lib/core/utils/run_guarded_async.dart`** — On failure, optional toast with Share/Report; passes `errorSummaryEnglish ?? logMessage` into reports and anonymized error telemetry when `ref` is supplied.

### Core widgets

Shared widgets in `lib/core/widgets/`: **AsyncValueBuilder**, **AppFab** (cartoony shared FAB: squash/stretch press, leaf burst on tap, finite icon wiggle + occasional idle flower/sunflower/dandelion blooms; gated by Settings → Extra animations (`extraAnimationsEnabledProvider`), `UiPerf.preferReducedChromeMotion`, and `AppFab.enableAmbientNature`; cheap shadows on iOS web; used on home, group detail, invite management, scanner pages), **CelebrationHost** (`core/celebration/`: one-shot nature overlays for first/new expense, settlement, person join/leave; join/leave deduped via `CelebrationDedupe` + `MembershipCelebrationBinder` so sync rebuilds do not loop), **BackButtonKeyboardDismiss**, **ConnectionBanner**, **CurrencyPickerList**, **ErrorContentWidget** (Share / Report issue; optional `summaryEnglish` for GitHub title), **ExpandableSection**, **FloatingNavBar**, **AppSidenav**, **ShellMenuButton**, **SheetOptionTile** / **SheetOptionList**, **PwaInstallBanner** / install guide sheet, **ServicesStatusSheet**, **SyncStatusChip** (`sync_status_icon.dart`), **Toast** (`toast.dart`: `showErrorWithActions` dismisses the toastification overlay before awaiting share / external browser on Android to avoid a stuck hit target at the bottom of the screen).

### Layout (core/layout)

- **LayoutBreakpoints** (`layout_breakpoints.dart`) — width breakpoints (tablet ≥600px, desktop ≥840px), content max widths (600/720), permanent shell sidenav width (240; mid band 0), and **`contentBandMetrics(context, contentAreaWidth)`** returning `(leftOffset, contentMaxWidth)` so the app bar title and body share the same horizontal band. Shell nav: `FloatingNavBar` (phone), temporary drawer + `ShellMenuButton` (mid), `AppSidenav` (desktop).
- **ConstrainedContent** (`constrained_content.dart`) — on tablet+ wraps [child] in a centered band using `contentBandMetrics`; on narrow screens returns [child] unchanged. Body content is wrapped in this so it does not span full width on large screens. Optional [aside] (e.g. page section index) sits in the **end** gutter (right in LTR, left in RTL) when that gutter is wide enough.
- **ContentAlignedFabLocation** (`content_aligned_fab_location.dart`) — positions the scaffold FAB at the end of the content band on wide layouts (RTL-aware); falls back to `endFloat` when the end gutter is tight.
- **ContentAlignedAppBar** (`content_aligned_app_bar.dart`) — a `PreferredSizeWidget` that places the title in the same horizontal band as the body (via `contentBandMetrics`). The title is absolutely positioned so it is not affected by leading/actions width. Default `centerTitle: true` (symmetric insets); group detail uses `centerTitle: false` so the name start-aligns (LTR/RTL) and can use space up to the actions before ellipsis. Titles use the normal app bar text size (no `FittedBox` shrink-to-fit); long **user-generated** titles should use [`UserText`](../lib/core/widgets/user_text.dart) (`maxLines` / ellipsis + content-based direction). Use with a **LayoutBuilder** around the scaffold and pass `layoutConstraints.maxWidth` as `contentAreaWidth`. Used on all pages that have an app bar and `ConstrainedContent` body (home, settings, group detail/settings/create, invite management/scan/accept, archived groups, expense form, privacy policy).
- **UserText / user_text utils** — display helpers for multilingual UGC (expense titles, group/participant names, notification copy). See [I18N.md](I18N.md) § User-generated content.

### Images + Receipt AI (core/receipt)

Expense form **photos**: add up to 5 images (camera or gallery on all platforms, including web). Client-side compression (`receipt_image_compress`) before upload; upload from bytes (`receipt_storage_upload`: `uploadExpenseImageBytesToStorage` in io/stub) so web can upload without file paths. Optional **Scan receipt** (mobile): long-press a photo to run OCR/LLM (`processReceiptBytes` → `receipt_scan_service`). Local image storage helper (`receipt_storage`) is used for scan temp copies. The `core/receipt` package contains generic expense image handling plus scan-specific OCR/LLM flow: **scan** (`receipt_scan_service`), **LLM** (`receipt_llm_service`), **image view** (`receipt_image_view`), **providers** (`receipt_providers`). Used by expense form and settings (Receipt AI). Platform-specific impls in `*_io.dart` / `*_stub.dart`.

## Navigation and Deep Links

- Router: `lib/core/navigation/app_router.dart`
  - onboarding redirect guard
  - shell route for home/settings tabs; `/profile` is a shell child (like `/archived`) opened from the sidenav avatar
  - group/invite/expense routes
  - **Navigation trace** (`navigation_trace.dart`): `GoRouter`’s `routerDelegate` listener records recent locations (UTC + URI) for **Share / Report issue** payloads (`error_report_helper.dart`). Decorative-only URL updates that do not change the delegate may not appear in the trace.
- **Group / personal create wizard:** Canonical routes are `/groups/create` and `/groups/create-personal` (each mounts one `GroupCreatePage` so `PageView` state is not disposed between steps). Legacy paths such as `/groups/create/details` **redirect** to the canonical URL (bookmarks still work; refresh on a legacy step URL restarts the wizard at step 0). In-wizard step labels in the address bar use `SystemNavigator.routeInformationUpdated` (decorative), not `context.go`, so state and animations stay intact. Step UI uses 0.6.x flat-panel surfaces (`AccentSurfaces`), `GroupSectionHeader`, living progress dots, `AppMotion` / `UiPerf` chrome, and `WizardStepEnter` (shared with onboarding).
- **Onboarding wizard:** Per-step routes (`/onboarding/welcome`, …) remain for deep links and cold starts; swiping between steps updates the browser URL the same way (**decorative** `routeInformationUpdated`) so `OnboardingPage` state is not recreated by `go()` on every page.
- **Group detail tabs:** Tab changes still use `SystemNavigator.routeInformationUpdated` in `group_detail_page.dart` (same pattern: URL reflects tab without replacing the route).
- **Modals/sheets:** `lib/core/layout/responsive_sheet.dart` — `showResponsiveSheet` (bottom sheet on narrow, centered dialog on tablet+) and `showAppDialog`; both support `centerInFullViewport` and **click-outside-to-close** (barrier dismiss on all platforms, including desktop web via an explicit barrier gesture). See [MODAL_CENTERING_AND_RESPONSIVE_SHEET.md](MODAL_CENTERING_AND_RESPONSIVE_SHEET.md).
- **Page / window motion:** Shared tokens and builders in `lib/core/motion/app_motion.dart` (`page` 280ms, `shellTab` 200ms, `modal` 320ms, `shellNav` 280ms). GoRouter helpers in `lib/core/navigation/app_page.dart`:
  - **Fade + end-slide** (`appFadeSlidePage`) for hierarchical pushes (groups, invites, profile, archived, forms, etc.) and via `PageTransitionsTheme` for scanner `MaterialPageRoute`s.
  - **No transition** (`appNoTransitionPage`) for IndexedStack roots (`/`, `/home/:mode`, `/settings`), onboarding step routes, and expense detail paging (`/groups/.../expenses/:eid` and invite preview `:eid`) so in-page slides / PageViews are not double-animated. Expense detail uses an interactive [PageView] in `ExpenseDetailShell` (live adjacent-expense peek while swiping; URL sync via decorative path); first-open enter still runs inside the shell.
  - **Shell tabs:** `MainScaffold` keeps home/settings always mounted (`Offstage` + `TickerMode` when on profile/archived) and crossfades on index change only.
  - **Managed back** on settings/profile/archived uses `context.go(home)` — no reverse page transition on that path (intentional). Nested profile expenses AppBar `pop` still reverses.
  - **Dialogs:** `showAppDialog` defaults to fade+scale (parity with wide sheets); pass `fadeScale: false` for fullscreen image viewers.
  - Decorative URL updates for group tabs / onboarding / create wizards must not use `go`/`push` for in-flow step changes (same as before).
- **App bar title alignment:** Pages that use `ConstrainedContent` for the body use **ContentAlignedAppBar** (see Layout above) so the app bar title sits in the same horizontal band as the content (tablet/desktop with rail and max-width content).
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
- Strings live in `assets/translations/en.json` and `ar.json` (same key set). Production UI uses `.tr()`; keep both locale files in lockstep when adding keys.
- Special cases (FCM background isolate English fallbacks, debug menu, bug-report English markdown, stored default participant names): see [I18N.md](I18N.md).
- Directional Material icons (`Icons.arrow_back`, `Icons.chevron_right`, etc.) already set `IconData.matchTextDirection`; do **not** pass `matchTextDirection` on the `Icon` widget (that named arg is not on `Icon` in current Flutter). Layout helpers (`ConstrainedContent.aside`, `ContentAlignedFabLocation`) place trailing chrome on the **end** side so Arabic mirrors correctly.

## Authentication

`lib/core/auth/auth_service.dart` supports:

- email/password sign-in and sign-up
- magic link sign-in
- Google and GitHub OAuth
- profile metadata update (`full_name`, `avatar_id`)
- resend confirmation

Redirect behavior:

- Web uses `SITE_URL` if provided (`authRedirectUrl`). If `SITE_URL` is mistakenly `http://` while the page origin is `https://` on the same host, the app upgrades the redirect to the current origin so OAuth does not bounce through an http→https 301.
- Native uses deep link callback `io.supabase.hisab://callback`.

**Web OAuth return path** (`lib/main.dart` + `lib/core/auth/oauth_*.dart`):

- Stock `Supabase.initialize` still runs with default `detectSessionInUri: true` (Safari/production happy path).
- `_finalizeWebOAuthReturn` then: if auth params remain and there is still no session, retries `getSessionFromUrl` once (20s timeout); sets `pendingWebOAuthCallbackError` for toast keys `auth_oauth_callback_failed` / `auth_oauth_timeout`; always clears auth query/hash params via `clearWebAuthCallbackParams` so a refresh cannot reuse a spent code.
- `App` shows the pending toast from the navigator context after first frame.

## Notifications (FCM + in-app history)

Push notifications are sent when expenses are added/content-edited/deleted or members join a group. The pipeline is: **Supabase (trigger) → pg_net → send-notification Edge Function → (1) insert `user_notifications` rows → (2) Firebase Cloud Messaging → Flutter**. Full setup and verification are in [SUPABASE_SETUP.md](SUPABASE_SETUP.md) (Section 5: send-notification, “Push notifications: end-to-end flow and verification”, and Section 9: “Push notifications not received”).

**Flutter** (`lib/core/services/notification_service.dart`):

- Requests notification permission; registers/unregisters FCM token in Supabase `device_tokens` (upsert on `user_id,token`), including the current app `locale` for language-aware notifications.
- Handles token refresh, foreground display (mobile: local notifications), and tap → navigate to group detail using `message.data['group_id']`.
- Expects incoming messages to have `notification` (title, body) and `data.group_id` (string).

**In-app activity feed:** The same Edge Function persists one `user_notifications` row per recipient (including when FCM is dry-run or the user has no device token). SyncEngine fetches the signed-in user’s rows into local SQLite; Profile (`features/profile`) shows a grouped feed and mark-as-read. Migration: `20260729010000_user_notifications.sql`.

**Backend:** Database trigger `notify_on_expense_change` (`AFTER INSERT OR UPDATE OR DELETE ON expenses`) and `notify_on_member_join` call `notify_group_activity()`, which POSTs to the `send-notification` Edge Function with `group_id`, `actor_user_id`, `action`, `group_name`, and optional expense fields (including `expense_id`). **Image-only / `updated_at`-only expense updates are skipped** (avoids a second Profile row when creating an expense with photos). **Personal groups** and **missing groups** (CASCADE delete) skip the HTTP call. Actions: `expense_created`, `expense_updated`, `expense_deleted`, `member_joined`. Copy: notification title is the group name; body is `{expense title} - {cost}` with localized `Edit` / `Deleted` prefixes. The Edge Function excludes the actor so only **other** group members receive push/history. Title/body are localized per recipient `locale` (en/ar; fallback en).

**Web:** `web/index.html` loads Firebase compat SDKs **asynchronously** and sets `window.__hisabFirebaseReady`; `web/flutter_bootstrap.js` waits on that promise before booting Flutter (faster first paint). `web/firebase-messaging-sw.js` handles background push and clicks. Web token registration requires `FCM_VAPID_KEY` at build time. On iPhone/iPad (all browsers use WebKit), push is gated until the user installs the Home Screen PWA and opens it from there (`pwaNotificationSupport`).

**Settings:** `notifications_enabled` controls FCM initialization and token registration; the toggle is shown only in online mode. In-app history still syncs when present on the server.

**Transaction Scanner:** Separate from FCM — Android Notification Listener → local drafts → personal expenses. See [TRANSACTION_SCANNER.md](TRANSACTION_SCANNER.md).

## Feature Modules

- `features/home`: groups list (Personal and Groups sections) via **home_list_provider** (ordered list, pinned/custom order), **`HomeReorderableGroupsSliver`** (long-press reorder with pin-cohort clamping in `home_list_reorder.dart`; optimistic order via `homeListPendingOrderIdsProvider` until settings persist), **routes**, create FAB + modal (Create group / Create personal), manual refresh trigger
- `features/profile`: `/profile` dashboard (account header moved from Settings, global display-currency net, KPIs, balances, personal budgets, grouped `user_notifications` feed). Data loads through **`profile_data_providers`** (`allExpensesProvider` / `allParticipantsProvider` / `myMembershipsProvider` → `profileDataSnapshotProvider`) so the dashboard and “my expenses” share one snapshot instead of N per-group streams. Repositories expose `watchAll` / `watchMyMembers` (web uses fingerprint-gated polling). SyncEngine fetches notifications by user.
- `features/groups`: create/detail/settings (including personal vs group branches and convert flows), invite management, invite acceptance; group settings include permission toggles (e.g. Members can add expenses, Members can record settlements for others). **Group create** uses a single shell route per flow plus decorative step URLs (see Navigation); create wizard chrome matches 0.6.x onboarding (`AccentSurfaces`, `WizardStepEnter`, `AppMotion` / `UiPerf`). `invite_redirect_proxy` (and `invite_redirect_proxy_web`, `invite_redirect_proxy_stub`, `invite_redirect_proxy_page`) for web/invite redirect; **create_invite_sheet** (invite creation UI)
- `features/expenses`: create/edit/detail expenses (**expense_detail_shell** with interactive PageView paging), split logic UI, image input hooks; **expense_form_constants**, **category_icons**
- `features/balance`: you-centric balance list (Your balance hero → everyone else → Settle Up) and record settlement flow. By default only the group owner or the debtor (participant who owes) can record a settlement; group setting **Members can record settlements for others** (Group.allowMemberSettleForOthers) allows any member to record. Balance list (`balance_list.dart`) uses `myMemberInGroupProvider` and `myRoleInGroupProvider` for the hero (when linked) and to enable or disable the record button per row.
- `features/settings`:
  - Account section links to `/profile` (account UI lives on Profile); **account_mode_actions**, **edit_profile_sheet**
  - theme/language/font/favorite currencies
  - local-only toggle + migration
  - import/export backup (**backup_helper** schema v1/v2, **backup_service**, Minimal JSON/CSV vs Full ZIP+HTML; force-queue silent `pending_writes` + notify-suppress)
  - telemetry + notifications toggles
  - logs viewer/clear/report flow
  - feedback / bug report (**feedback_upload** shared web+native, feedback_clipboard io/web; `submitUserBugReport` in error_report_helper; optional screenshot prompt via `ss_preventer` on iOS/Android 14+)
  - About: version row tappable to check for updates manually; About me shows developer info from GitHub (avatar, name, bio, profile link)
- `features/onboarding`: multi-step onboarding (welcome, preferences, permissions, connect) with mode selection and auth gate for online mode; step UI uses 0.6.x flat-panel surfaces (`AccentSurfaces`), brand hero + staggered welcome rows, and `WizardStepEnter` motion (UiPerf-gated; `lib/core/widgets/wizard_step_enter.dart`, aliased as `OnboardingStepEnter` in onboarding shared); URL sync for steps is decorative (see Navigation) so wizard state is preserved while swiping
- `features/transaction_scanner`: Android notification → draft → personal expense (Settings hub; local-only tables). See [TRANSACTION_SCANNER.md](TRANSACTION_SCANNER.md).

## Settings Framework

Definitions live in `lib/features/settings/settings_definitions.dart`.

Major persisted keys include:

- appearance: `theme_mode`, `theme_color`, `language`, `font_size_scale`, `favorite_currencies`
- mode/lifecycle: `local_only`, `onboarding_completed`, pending OAuth flags, pending invite token
- privacy: `telemetry_enabled`, `notifications_enabled`
- receipt AI: OCR/AI flags, provider, and API keys

## Web and PWA

- PWA manifest: `web/manifest.json`
- Web bootstrap: `web/flutter_bootstrap.js` (custom bootstrap; loads Flutter without default service-worker settings)
- PowerSync web assets: `web/sqlite3.wasm`, `web/powersync_db.worker.js` (single worker for DB + sync; refresh with `flutter pub run powersync:setup_web`)
- Boot splash: `#hisab-boot-splash` in `web/index.html` (avoids a blank screen while Flutter / OAuth return loads); removed when the app mounts.
- PWA install UX (replaces the old `pwa_install` package):
  - `lib/core/pwa/` — `PwaInstallMode` / `PwaNotificationSupport`, stub vs web capability APIs (`isPwaStandalone`, `canPromptPwaInstall`, `promptPwaInstall`, listeners)
  - `window.hisabPwa` in `web/index.html` — captures `beforeinstallprompt`, reports standalone/iOS/Android/mobile, prompts install
  - `PwaInstallBanner` + `PwaInstallGuideSheet` — native Chromium prompt on Android when available; otherwise platform-specific Add-to-Home-Screen steps (iOS Share menu / Android browser menu)
  - Web push on iPhone/iPad is gated until the Home Screen PWA is opened (`pwaNotificationSupport == needsInstall`); `PermissionService` then shows an install sheet instead of a no-op browser prompt
  - Unit coverage: `test/core/pwa_capabilities_test.dart`, `test/core/pwa_install_banner_widget_test.dart`
- Invite links use the web app domain (e.g. hisab.shenepoy.com) when `INVITE_BASE_URL` is set. On deploy, the route `/functions/v1/invite-redirect` is served by **Firebase Hosting** via a rewrite to static `invite-redirect.html` (built from `web/invite-redirect-template.html`); that page redirects to the Supabase Edge Function, which validates the token and redirects the user to `redirect.html`. This works on the Firebase free (Spark) plan with no Cloud Function. When the user is already inside the web app, the same path is handled by the Flutter app (GoRouter), which redirects to the Supabase Edge Function.
- Invite redirect static page: `web/redirect.html`
  - desktop -> web invite route
  - mobile -> attempts app deep link with timed web fallback
- Invite/OG assets: `web/invite-redirect-template.html`, `web/og-invite.png` (used in invite link and OG image flow; see [EDGE_FUNCTIONS.md](EDGE_FUNCTIONS.md)).
- Public privacy page: `web/privacy/index.html`
- Account deletion is described in `docs/DELETE_ACCOUNT.md`; the in-app options are Delete local data and Delete cloud data under Settings > Advanced (and a public page at `web/delete-account/index.html` when deployed).
- Deployment cache control is configured in `firebase.json`: entry scripts/manifest/SW/invite HTML + catch-all `**` use `max-age=0, must-revalidate` (Firebase matches header `source` on the **request path before rewrites**; default HTML cache is one hour). Hosting deploys via GitHub Actions tag releases.

## Supabase Backend Contract

This repo is the **source of truth** for all Supabase Edge Functions. See [EDGE_FUNCTIONS.md](EDGE_FUNCTIONS.md) for the list and deploy commands.

- `supabase/functions/invite-redirect/index.ts` — validates invite token and redirects to `redirect.html`
- `supabase/functions/og-invite-image/` — GET `?token=...` returns 1200×630 PNG (QR code, branding) for invite link previews; deploy with `--no-verify-jwt`
- `supabase/functions/send-notification/index.ts` — persists `user_notifications` and sends FCM push (expense create/update/delete, member_joined; excludes actor)
- `supabase/functions/telemetry/index.ts` — accepts anonymous usage telemetry events

On the free plan, invite redirect uses only static Hosting files (`invite-redirect.html` + `redirect.html`). A **Firebase Cloud Function** can optionally serve the same path with dynamic OG meta for crawlers (see [EDGE_FUNCTIONS.md](EDGE_FUNCTIONS.md) for `functions/` and hosting rewrites).

The app also depends on Supabase-side schema, RLS, and RPCs documented in `docs/SUPABASE_SETUP.md`, including:

- tables such as `groups`, `group_members`, `participants`, `expenses`, `expense_tags`, `group_invites`, `invite_usages`, `telemetry`, `device_tokens`, `user_notifications`
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
| **jj** (`user-jj`) | Jujutsu VCS: repo status, log, diff, show; bookmarks (list/create/set/delete/move); commit, describe, edit, new; rebase, squash, split, duplicate, abandon; file list/show; git clone/fetch/push; config; workspace list/add; operation log/undo; resolve. Prefer over running `jj` in a shell when the AI needs to inspect or modify the repo. |
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

### How to use jj MCP

The **jj** (Jujutsu) MCP server (`user-jj`) exposes Jujutsu VCS operations so the AI (or you) can query and modify the repo without running `jj` in a shell. The server runs from the workspace root (or use `working_directory` on tools that support it).

1. **Server and repo**  
   In Cursor the server appears as **`user-jj`**. Use that name when calling jj MCP tools. The repo root is shown by `jj_root` (optional `working_directory` to override).

2. **Common operations**
   - **Status and history:** `jj_status` — working copy and conflicts; `jj_log` — revision history (optional `revisions`, `paths`, `limit`, `patch`, `summary`); `jj_show` — one revision’s description and patch; `jj_diff` — compare between revisions (`from`/`to` or `revisions`).
   - **Commits and changes:** `jj_commit` — create/update change (e.g. `message`); `jj_describe`, `jj_edit`, `jj_new`; `jj_rebase`, `jj_squash`, `jj_split`, `jj_duplicate`, `jj_abandon`.
   - **Bookmarks:** `jj_bookmark_list`, `jj_bookmark_create`, `jj_bookmark_set`, `jj_bookmark_delete`, `jj_bookmark_move`.
   - **Files:** `jj_file_list`, `jj_file_show`.
   - **Git:** `jj_git_clone`, `jj_git_fetch`, `jj_git_push`.
   - **Other:** `jj_config_get` / `jj_config_set` / `jj_config_list`; `jj_workspace_list` / `jj_workspace_add`; `jj_operation_log` / `jj_operation_undo`; `jj_resolve`; `jj_version`.

3. **Tool schemas**  
   Before calling a tool, read its descriptor under `.cursor/projects/<workspace>/mcps/user-jj/tools/<tool_name>.json` for required/optional arguments (e.g. `working_directory`, revsets, paths).

4. **When to use**  
   Prefer jj MCP for status, log, diff, commit, and bookmark operations from the IDE so the AI can reason about and change the repo without manual terminal steps.

5. **Step-by-step: when the AI (or you) edit something**  
   Use this flow so edits are reflected in jj and recorded as a change:

   - **Step 1 (optional):** `jj_status` — see working copy and any conflicts before editing.
   - **Step 2:** Edit files (StrReplace, Write, etc.). Changes exist only on disk until jj records them.
   - **Step 3:** `jj_status` — confirm which files/changes jj sees in the working copy.
   - **Step 4:** `jj_show` — review the current change (revision `@` = working copy). Or `jj_diff` with `revisions: "@"` to see the diff. Fix anything if needed.
   - **Step 5:** `jj_commit` with `message: "Short description of the edit"` — creates/updates the change and attaches that description. The change is now in the repo history.

   The AI calls these via `call_mcp_tool` with `server: "user-jj"` and `toolName` (e.g. `jj_status`, `jj_commit`) plus the tool’s `arguments` from its JSON descriptor. To start a new change before editing (e.g. for a separate branch/change), use `jj_new` first, then edit, then `jj_commit`.

## Configuration

Build-time config is via `--dart-define` in `lib/core/constants/supabase_config.dart`:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `INVITE_BASE_URL` (optional)
- `SITE_URL` (optional auth email redirect)
- `FCM_VAPID_KEY` (web push)

Secrets template: `lib/core/constants/app_secrets_example.dart`; see `docs/CONFIGURATION.md` for runtime configuration. If Supabase defines are missing, app runs local-only by design. In local mode, no environment variables are required and the app must not crash or throw.

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
- **security-check** / **infra-check**: static gates (`scripts/verify_security.sh`, `scripts/verify_infra.sh`); required before Android/web deploy
- **test** job: unit + widget tests, local-only integration tests on web (Chrome)
- **test-online** job: online integration tests against a local Supabase Docker instance (auth, sync, invite flows)
- builds Android APK + AAB
- creates GitHub release (tag flow)
- optional Play Store internal deploy
- builds/deploys Flutter web to Firebase Hosting (copies privacy page to build output)

Agent pre-release gate (scripts + Supabase advisors + security-review): [`.cursor/skills/hisab-release-checks/SKILL.md`](../.cursor/skills/hisab-release-checks/SKILL.md). Local: `bash ./scripts/run_release_checks.sh`.

The `test-online` job requires no additional secrets — it uses the local Supabase instance's auto-generated credentials. It sets up the Supabase CLI, starts Docker containers, resets the database (migrations + seed), and runs `flutter drive` with the online test barrel.

## Key Dependencies (Selected)

- state: `flutter_riverpod`, `riverpod_annotation`
- navigation: `go_router`
- **Git deps:** `flutter_logging_service` (siglat), `flutter_settings_framework` (edadat) — pinned to `ref: main` in pubspec for CI; local path override (lock not committed) is used for fast iteration on those packages. Optional: publish to pub.dev or vendor into this repo for long-term reproducibility.
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
  - **Widget:** Public custom widgets under `test/` mirroring `lib/`: `test/core/` (async_value_builder, back_button_keyboard_dismiss, connection_banner, currency_picker_list, expandable_section, floating_nav_bar, invite_link_handler, pwa_install_banner, pwa_capabilities, sync_status_chip), `test/groups/` (group_card, create_invite_sheet), `test/expenses/` (expense_list_tile, expense_title_section, expense_amount_section, expense_split_section, expense_bill_breakdown_section, expense_detail_body, expense_detail_body_header), `test/settings/` (logs_viewer_dialog, privacy_policy_page), `test/pages/` (main_scaffold, home_page, archived_groups_page), `test/balance/` (balance_list: settlement permission — owner vs member/debtor), `test/onboarding/` (onboarding_page), plus error_content and app. Widget tests use EasyLocalization + MaterialApp; Riverpod widgets use ProviderScope with overrides when needed. See [test/widget_test_helpers.dart](../test/widget_test_helpers.dart) and [test/README.md](../test/README.md).
  - **Locale:** Key widgets are tested in both English and Arabic via `test/widget_test_helpers.dart`: `pumpApp(tester, child: ..., locale: Locale('ar'))` and `testSupportedLocales`. Edge cases (empty/zero/long content, optional params) are covered where relevant. Translation file parity: `test/translations_test.dart` (see [I18N.md](I18N.md)).
  - **Integration-style:** Local PowerSync DB, sync engine with fake backend. See [test/README.md](../test/README.md) for PowerSync native binary requirements and coverage (`flutter test --coverage`).
  - **Integration (local-only):** Full-app flows in `integration_test/` — smoke, onboarding, group, personal, expense (tags, photos, currencies, bill breakdown), balance (settlements, freeze), settings. Run with `flutter drive` on web or `flutter test integration_test/ -d <device>`. See [test/README.md](../test/README.md).
  - **Integration (online):** Full end-to-end tests against a **local Supabase instance** (Docker) — auth (sign-in/out), data sync (create group/expense → verify in Supabase DB), and multi-user invite flow. Run with `./scripts/run_online_tests.sh` or manually via `supabase start` + `flutter drive`. See [test/README.md](../test/README.md) for full setup.
- **Widget test helper:** `test/widget_test_helpers.dart` provides `pumpApp(tester, child, locale?, pumpAndSettle?)` to wrap the widget in EasyLocalization + MaterialApp; use for presentational widgets. For widgets that depend on Riverpod, build ProviderScope + EasyLocalization + MaterialApp inline with overrides (see e.g. `test/balance/balance_list_widget_test.dart`).
- **Generated code:** Run `dart run build_runner build` (or `watch`) to regenerate `.g.dart` files before running tests or when changing providers/settings.

## Development

- **Codegen:** Use `dart run build_runner build` after changing Riverpod providers, settings, or other annotated code so `.g.dart` files stay in sync.
- **Tooling:** Prefer the Dart, Supabase, and jj MCP servers (see “MCP available in the IDE” above) for analysis, format, schema checks, migrations, and version control (status, log, commit, bookmarks) instead of running CLI tools manually.

## Recent improvements (documented changes)

The following improvements are reflected in the codebase and docs:

- **Sync:** DataSyncService retries sync on transient errors (up to 3 attempts with backoff). Auth errors (401/403) do not retry and set a “sync failed” UI status. See `lib/core/database/sync_errors.dart` and `SyncStatus.syncFailed` in `lib/core/services/connectivity_service.dart`.
- **Error UX:** Default async error title is localized (`generic_error`). Shared `ErrorContentWidget` (with optional retry and optional `summaryEnglish` for GitHub) is used for error states in balance, group detail, invite accept/management, archived groups, expense form, and group settings. See `lib/core/widgets/error_content.dart`. Share/Report payloads and English structure: `error_report_helper.dart`, route history `navigation_trace.dart`, listener in `app_router.dart`. Error toast (`showErrorWithActions`) dismisses the overlay before awaiting share / browser on Android.
- **Group create & onboarding navigation:** Single canonical `GoRouter` path per create wizard; step URLs use `SystemNavigator.routeInformationUpdated` where needed so `PageView` state is not disposed by `go()` between steps. Legacy create URLs redirect to canonical routes. See `app_router.dart`, `group_create_page.dart`, `onboarding_page.dart`.
- **App bar titles:** `ContentAlignedAppBar` no longer scales titles down with `FittedBox`; group detail app bar applies grapheme-safe elision + `TextOverflow.ellipsis`. See `content_aligned_app_bar.dart`, `group_detail_page.dart`.
- **Backup import/export:** Settings → Data & Backup. **Minimal** export: JSON (schema v2, restorable) or CSV (spreadsheet only). **Full** export: ZIP with `backup.json`, `report.html`, `expenses.csv`, optional `receipts/`. Import accepts JSON or ZIP (not CSV); modes **Add as copies** (default) or **Replace local** (local-only only). Import uses force-queue writes (`runWithSilentPendingWrites`), pauses `DataSyncService`, strips remote image URLs, remaps `splitShares` / settlement snapshot (incl. expense IDs). Silent `pending_writes` push calls `set_notify_suppress` so `notify_group_activity` skips `send-notification`. See `lib/features/settings/backup_*.dart`, migration `20260731120000_user_notify_suppress.sql`.
- **Accessibility:** Semantics/semanticsLabel added for main actions (create group, scan invite, archived, open group, add expense/participant, record settlement) and for the sync status chip. See home, group card, group detail, balance list, sync_status_icon. When the user cannot record a settlement (not owner and not debtor), the balance list uses `record_settlement_restricted` for tooltip/semantics.
- **Tests:** Unit tests (sync errors, backup parse, domain, settle-up, translations). Widget tests cover public custom widgets (core, groups, expenses, settings, pages) with a shared helper `pumpApp()` and locale/edge-case coverage (en/ar, empty/zero/long). See `test/widget_test_helpers.dart` and `test/README.md`. CODEBASE “Testing” and “Development” sections describe how to run tests and use build_runner/MCP.
- **Config/docs:** Receipt AI API keys documented as user-provided and device-only in `docs/CONFIGURATION.md`. Custom `ErrorWidget.builder` in `main.dart` for framework build errors.
- **Expense split UX:** In the expense form, when split type is **Parts**, each participant row has minus/plus buttons to adjust the part value (0–999) without typing. **Amounts** and **Parts** rows use a single field per participant (the separate “formatted amount” column was removed); the “Total: X / Y” line remains for amounts validation. See `lib/features/expenses/widgets/expense_split_section.dart`.
- **Amounts split: preserve manual amounts:** When editing one participant’s amount then another’s, the first value is no longer overwritten. The form tracks which participants the user has manually edited (`_amountsManuallySetIds`); redistribution only updates participants not in that set. The set is cleared when the expense total changes, when a participant is excluded, or when split type changes. See `lib/features/expenses/pages/expense_form_page.dart` (`_applyAmountsChange`, `_amountsManuallySetIds`, `_lastAmountCentsForAmounts`).
- **Amounts split: 0.01 rounding fix:** Equal splits and redistribution use integer cents so the sum of displayed amounts equals the expense total exactly (e.g. 500 among 3 shows 166.67, 166.67, 166.66). Applied in `_ensureCustomSplitValues` (amounts branch) and `_applyAmountsChange` (equal and proportional branches); helper `_formatCentsAsAmount` formats cents for display.
- **Amounts split: fill on blur:** If an amount field is 0 or empty and the user leaves the field (blur), it is auto-filled with the remainder (total minus the sum of the other participants’ amounts) so the total matches. No redistribution; only that field is updated. Implemented via a focus-node listener in the expense form; see `_handleAmountFieldUnfocused` in `lib/features/expenses/pages/expense_form_page.dart`.
- **Personal (my-expenses-only) feature:** Groups can be created or converted to “personal” mode: single participant, optional budget, minimal UI (no Balance/People tabs, no split or invite). Create via FAB modal (Create group / Create personal); convert in settings (Share as group / Use as personal; group→personal revokes invites). Data: `Group.isPersonal`, `Group.budgetAmountCents`; schema and sync include both; backup/restore and i18n covered. See `docs/PERSONAL_FEATURE.md`.
- **Back button dismisses keyboard:** When the keyboard is visible, the first back press (Android) only closes the keyboard and does not navigate. Implemented app-wide via `BackButtonKeyboardDismiss` in `lib/core/widgets/back_button_keyboard_dismiss.dart`, registered in the router builder so it runs before route-specific back handling.
- **Anonymize participant name on account deletion only:** When a user's auth account is deleted (e.g. after an account deletion request), a database trigger runs and replaces their participant display name in all groups with a random placeholder (e.g. "Former member a3f2b1") and clears avatar, so expense history shows a neutral label. Leave/kick/archive do not change names. See migration `20250101000017_anonymize_on_delete.sql` (trigger on `auth.users` DELETE).
- **Upgrader logging:** Debug logging from the upgrader package is disabled. The app logs one aggregated line per update check (manual from Settings > About and automatic via UpgradeAlert) via the logging service. See `lib/app.dart` (`debugLogging: false`, `willDisplayUpgrade`, and the manual-check callback).
- **CODEBASE doc:** This overview was updated to reflect current lib layout (core subdirs, domain barrel, repositories), SyncEngine/SyncBackend, core services/widgets/receipt, feature details, Edge Functions (including og-invite-image), web assets, and test layout.
- **Modal centering (web tablet/desktop):** Modals are centered in the full viewport by default (`centerInFullViewport` defaults to true). `showResponsiveSheet` and `showAppDialog` support `centerInFullViewport`; pass `false` for modals opened from home/settings that should stay in the content area next to the rail. The app builder uses `Positioned.fill` so the root navigator gets full viewport size. See `docs/MODAL_CENTERING_AND_RESPONSIVE_SHEET.md`.
- **App bar title aligned with content:** All pages with a constrained body use **ContentAlignedAppBar** so the app bar title sits in the same horizontal band as the body (same `contentBandMetrics` as `ConstrainedContent`). The title is absolutely positioned in the app bar so it is not affected by leading/actions; titles are not shrunk with `FittedBox` (use ellipsis / elision in the title widget). Wrap the scaffold in `LayoutBuilder` and pass `layoutConstraints.maxWidth` as `contentAreaWidth`. See `lib/core/layout/content_aligned_app_bar.dart` and the “Layout (core/layout)” section above.

- **Settlement permission:** By default only the group owner or the debtor (participant who owes) can record a settlement. Group setting **Members can record settlements for others** (`Group.allowMemberSettleForOthers`, default false) allows any member to record. Schema: `groups.allow_member_settle_for_others`; sync, repository, backup, and Migration 19 in `docs/SUPABASE_SETUP.md`; local Supabase migration `20250101000019_groups_allow_member_settle_for_others.sql`. Balance list and group settings UI enforce the rule. See `lib/features/balance/widgets/balance_list.dart`, `lib/features/groups/pages/group_settings_page.dart`, `lib/domain/group.dart`.
- **Online integration tests:** Full end-to-end tests against a local Supabase Docker instance — auth, sync, and invite flows. Local Supabase setup (config, migrations, seed) lives in `supabase/`. Run with `./scripts/run_online_tests.sh`. CI runs them in the `test-online` GitHub Actions job. See [test/README.md](../test/README.md) for full setup, prerequisites, and troubleshooting.
- **Invite RPC null-expiry fix:** `accept_invite` treats `expires_at IS NULL` as valid (never-expiring invites) and pre-filters inactive/maxed invites. Apply migration `20260306120000_fix_accept_invite_null_expiry_validation.sql` in local/dev environments so invite acceptance matches production behavior.
- **Duplicate participant guard:** Memberships stay unique via `group_members(group_id, user_id)`. Active linked participants are also unique via partial index `idx_participants_active_user_per_group` (`user_id IS NOT NULL AND left_at IS NULL`). `accept_invite` reuses by `user_id`, race-safely claims a unique unlinked placeholder (name/profile/first-token/email/local-part, min length 2), and maps membership races to “Already a member”; `merge_participant_with_member` unlinks the old row before claiming. Migration: `20260728130000_prevent_duplicate_active_participants.sql`.
- **i18n hardcode pass:** User-facing strings (scanner, notifications channel/fallbacks, language/theme labels, exchange-rate label, receipt/status defaults, relative times, feedback issue title, etc.) go through translation keys in both `en.json` and `ar.json`. Built-in scanner pattern names are stored as keys and shown via `scannerPatternDisplayName`. Conventions and intentional exceptions: [I18N.md](I18N.md).

## Related Docs

- `docs/MODAL_CENTERING_AND_RESPONSIVE_SHEET.md` - modal/dialog centering on web, `centerInFullViewport`, and responsive sheet API
- `docs/SUPABASE_SETUP.md` - complete backend bootstrap and SQL/RPC policy setup
- `docs/SUPABASE_BACKUP.md` - how to backup Supabase database (dashboard, pg_dump, script)
- `docs/EDGE_FUNCTIONS.md` - Supabase Edge Functions list and deploy commands (invite-redirect, og-invite-image, send-notification, telemetry)
- `docs/PERSONAL_FEATURE.md` - personal (my-expenses-only) mode: data model, flows, code locations, backup, i18n
- `docs/TRANSACTION_SCANNER.md` - Android notification → draft → personal expense scanner
- `docs/I18N.md` - localization conventions, key groups, en/ar parity, notification/scanner special cases
- `docs/CONFIGURATION.md` - runtime configuration quick reference
- `docs/RELEASE_SETUP.md` and `docs/PLAY_CONSOLE_DECLARATIONS.md` - release/distribution notes
- `docs/DELETE_ACCOUNT.md` - user-facing guide for deleting data and requesting account deletion
- `test/README.md` - comprehensive test documentation: unit, widget, integration (local + online), coverage
