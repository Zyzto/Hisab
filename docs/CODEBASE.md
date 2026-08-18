# Codebase overview

<!-- markdownlint-disable MD060 -->

Hisab is a Flutter app for group expense splitting and settlement. Local SQLite (PowerSync package) always starts; a cloud backend is optional and, in this repository, absent — auth, sync, invites and push come from a `CloudBackend` implementation supplied by a separate package.

Product and install overview: [../README.md](../README.md). Doc index: [README.md](README.md).

## Stack

- Flutter + Dart
- Riverpod (`riverpod_annotation`) for state and DI
- GoRouter for navigation
- Easy Localization (`en`, `ar`, RTL support)
- PowerSync package as local SQLite engine
- `packages/hisab_backend`: the backend contract (nine facets, neutral models)
- `packages/hisab_cloud`: the backend implementation — a no-op stub here
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
| `packages/hisab_backend/` | Backend contract: facet interfaces, neutral models, registry |
| `packages/hisab_cloud/` | Backend implementation. In this repository a stub that registers nothing |
| `docs/` | Setup and architecture documentation; see [docs/README.md](README.md) for an index |
| `test/` | Tests mirroring `lib/` layout; see [test/README.md](../test/README.md) |
| `integration_test/` | Full-app integration tests, backend-free; see [test/README.md](../test/README.md) |
| `scripts/` | Helper scripts (`run_all_tests.sh`, `verify_*`) |
| `scripts/ci/` | One-line build and check steps shared by CI and local runs |
| `tool/` | Dart runners (`run_all_tests.dart`, `score_ocr_dirs.dart`) and debug-icon generator |
| `assets/tessdata/` | Bundled Tesseract traineddata (`eng`+`ara`) for Android on-device OCR |
| `assets/images/parallax/` | Onboarding meadow layers (hybrid WebP: lossy sky, lossless alpha) |
| `tmp/` | Local scratch (gitignored): OCR photos/outputs, tool previews |
| `.github/workflows/` | `ci.yml` (checks, tests, offline build guard) and `release.yml` (signed FOSS APKs on `v*` tags) |

## App Startup Flow

`lib/main.dart` boot sequence:

1. Flutter bindings, global error handlers, logging service, Easy Localization, image picker setup. On web, `web/index.html` exposes `window.hisabPwa` (install + capability detection) and shows a boot splash until Flutter mounts.
2. Settings framework (`flutter_settings_framework`) and reads persisted settings.
3. Initializes local SQLite (`PowerSyncDatabase`) unconditionally.
4. Calls `registerHisabCloud()`, then initializes the backend if one registered itself. With the stub, nothing happens and the app is local-only. On web, `_finalizeWebOAuthReturn` cleans auth callback URL params and retries session recovery once if the stock path left no session.
5. Resolves pending OAuth flags from settings (onboarding/settings web redirect flows).
6. Initializes Firebase (for FCM) when a backend is available.
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
- Reads come from local DB; online mode writes target the backend then the local cache.
- In online mode while temporarily offline, some writes (notably expense writes) are queued to `pending_writes`.
- **Expense exchange rate:** Each expense stores `exchange_rate` and `base_amount_cents` (group-currency amount). Display and settle-up **always** use these stored values so amounts stay consistent over time and when editing; do not recalculate from a live API for existing expenses.

**Schema alignment:** The source of truth for synced table columns is the INSERT column list in `lib/core/database/sync_engine.dart`. When adding or changing a column, keep all three in sync: (1) the server-side table definition, (2) `lib/core/database/powersync_schema.dart`, and (3) the corresponding INSERT in `sync_engine.dart`. PowerSync adds an `id` column automatically to each table — do not add a custom `Column.text('id')` in the schema (it will trigger an assertion). The test in `test/schema_alignment_test.dart` covers all eight synced tables (including user-scoped `user_notifications`).

### Domain

`lib/domain/domain.dart` is the barrel export. Main entities: `group`, `group_member`, `group_invite`, `invite_usage`, `group_role`, `participant`, `expense`, `expense_tag`, `receipt_line_item`, `split_type`, `transaction_type`, `settlement_transaction`, `settlement_item`, `settlement_method`, `settlement_snapshot`, `participant_balance`, `group_balance_result`, `delete_my_data_preview`, `user_notification`.

### Sync Layer

- **SyncEngine** (`lib/core/database/sync_engine.dart`): testable full fetch from the backend into the local DB and push of `pending_writes`; `SyncBackend` (`lib/core/database/sync_backend.dart`) is a typedef for the contract's `CloudSync` facet.
- **DataSyncService** (`lib/core/database/database_providers.dart`) uses SyncEngine and is active only when:
  - a backend is registered
  - app is not in effective local-only mode
  - user is authenticated
- Sync actions: pushes `pending_writes`, performs full fetch for member groups, refreshes every 5 minutes while online.

### Mode Model

- `local_only = true`: full local operation, no network dependency
- `local_only = false`: online mode (subject to auth/connectivity)
- `effectiveLocalOnly` also becomes true when no backend is registered

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

Expense form **photos**: add up to 5 images (camera or gallery on all platforms, including web). Client-side compression (`receipt_image_compress`) before upload; upload from bytes (`receipt_storage_upload`: `uploadExpenseImageBytesToStorage` in io/stub) so web can upload without file paths. Optional **Scan receipt** (Android/iOS when Settings → Receipt scan mode ≠ off): Scan button on thumbnails, long-press, auto-scan after attach, and **Stop** to cancel (`receipt_scan_cancel` + `processReceiptBytes` → `receipt_scan_service`). Modes: **local** (on-device OCR via `receipt_ocr` MethodChannel — native `ReceiptOcrBridge` using Tesseract4Android / Tess 5 on Android with bundled `assets/tessdata/`, Apple Vision on iOS — then `receipt_local_extractor`), **nano** (Gemini Nano / AI Core on Android via `receipt_nano_service` + device Check/Download), **cloud** (BYO Gemini/OpenAI via `receipt_ai_backend` / `receipt_llm_service`). Scan mode / provider prefs live in `settings_framework_providers` (not a separate receipt providers file). Web: attach/upload only; Receipt AI settings hidden. Capability matrix: `receipt_scan_capability.dart`. Other helpers: `receipt_storage`, `receipt_image_view`. Platform-specific impls in `*_io.dart` / `*_stub.dart`.

## Navigation and Deep Links

- Router: `lib/core/navigation/app_router.dart`
  - onboarding redirect guard
  - shell route for home/settings tabs; `/profile` is a shell child (like `/archived`) opened from the sidenav avatar
  - group/invite/expense routes (incl. group analytics)
  - **Last route restore** (`last_route_restore.dart`): restores the last in-app location after cold start when appropriate
  - **Navigation trace** (`navigation_trace.dart`): `GoRouter`’s `routerDelegate` listener records recent locations (UTC + URI) for **Share / Report issue** payloads (`error_report_helper.dart`). Decorative-only URL updates that do not change the delegate may not appear in the trace.
- **Group / personal create wizard:** Canonical routes are `/groups/create` and `/groups/create-personal` (each mounts one `GroupCreatePage` so `PageView` state is not disposed between steps). Legacy paths such as `/groups/create/details` **redirect** to the canonical URL (bookmarks still work; refresh on a legacy step URL restarts the wizard at step 0). In-wizard step labels in the address bar use `SystemNavigator.routeInformationUpdated` (decorative), not `context.go`, so state and animations stay intact. Step UI uses 0.6.x flat-panel surfaces (`AccentSurfaces`), `GroupSectionHeader`, living progress dots, `AppMotion` / `UiPerf` chrome, and `WizardStepEnter` (shared with onboarding).
- **Onboarding wizard:** Per-step routes (`/onboarding/welcome`, …) remain for deep links and cold starts; swiping between steps updates the browser URL the same way (**decorative** `routeInformationUpdated`) so `OnboardingPage` state is not recreated by `go()` on every page.
- **Group detail tabs:** Tab changes still use `SystemNavigator.routeInformationUpdated` in `group_detail_page.dart` (same pattern: URL reflects tab without replacing the route).
- **Modals/sheets:** `lib/core/layout/responsive_sheet.dart` — `showResponsiveSheet` (bottom sheet on narrow, centered dialog on tablet+) and `showAppDialog`; both support `centerInFullViewport` and **click-outside-to-close** (barrier dismiss on all platforms, including desktop web via an explicit barrier gesture). See [MODAL_CENTERING_AND_RESPONSIVE_SHEET.md](MODAL_CENTERING_AND_RESPONSIVE_SHEET.md).
- **Page / window motion:** Shared tokens and builders in `lib/core/motion/app_motion.dart` (`page` 280ms, `shellTab` 200ms, `modal` 320ms, `shellNav` 280ms). GoRouter helpers in `lib/core/navigation/app_page.dart`:
  - **Fade + end-slide** (`appFadeSlidePage` / `PageTransitionsTheme`) for hierarchical pushes and scanner `MaterialPageRoute`s; both share `AppMotion.buildHierarchicalPageTransition`. On iOS web (`UiPerf.preferFadeOnlyPageTransitions`) the end-slide is skipped (fade-only).
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
- First launch (no stored `language`): seed from device locale (`en`/`ar`) via `seedLanguageFromPlatformIfUnset` — see [I18N.md](I18N.md).
- `_LocaleSync` (in `main.dart`) updates Easy Localization locale when provider changes.
- `App` (`lib/app.dart`) intentionally reads locale from `context.locale` only.
- Router refreshes on locale changes via `localeRefreshNotifier`.
- Supported locales: English (`en`), Arabic (`ar`).
- Strings live in `assets/translations/en.json` and `ar.json` (same key set). Production UI uses `.tr()`; keep both locale files in lockstep when adding keys. JSON asset edits need hot **restart** / reinstall (not hot reload).
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
- Native uses deep link callback `com.shenepoy.hisab://callback` (legacy `io.supabase.hisab://callback` still accepted).

**Web OAuth return path** (`lib/main.dart` + `lib/core/auth/oauth_*.dart`):

- The backend's own initialization still handles the URI session by default (Safari/production happy path); the retry above only covers the case where it left no session.
- `_finalizeWebOAuthReturn` then: if auth params remain and there is still no session, retries `getSessionFromUrl` once (20s timeout); sets `pendingWebOAuthCallbackError` for toast keys `auth_oauth_callback_failed` / `auth_oauth_timeout`; always clears auth query/hash params via `clearWebAuthCallbackParams` so a refresh cannot reuse a spent code.
- `App` shows the pending toast from the navigator context after first frame.

## Notifications (FCM + in-app history)

Push notifications are sent when expenses are added/content-edited/deleted or members join a group. The client's half of the pipeline is token registration plus the in-app history table; the fan-out itself happens server side and is therefore backend-specific. The full chain is: **write lands on the server → server detects the change → (1) insert `user_notifications` rows → (2) Firebase Cloud Messaging → Flutter**. What a backend has to guarantee here is in [BACKEND_BEHAVIOUR.md](BACKEND_BEHAVIOUR.md) § Notifications.

**Flutter** (`lib/core/services/notification_service.dart`):

- Requests notification permission; registers/unregisters the FCM token through `cloudBackend.notifications`, including the current app `locale` for language-aware notifications.
- Handles token refresh, foreground display (mobile: local notifications), and tap → navigate to group detail using `message.data['group_id']`.
- Expects incoming messages to have `notification` (title, body) and `data.group_id` (string).

**In-app activity feed:** The server persists one `user_notifications` row per recipient, including when push is dry-run or the user has no device token, so the feed is not a side effect of push succeeding. SyncEngine fetches the signed-in user's rows into local SQLite; Profile (`features/profile`) shows a grouped feed and mark-as-read.

**Server side:** the fan-out is the backend's responsibility. What the client
assumes is: actions are `expense_created`, `expense_updated`, `expense_deleted`
and `member_joined`; the actor is excluded, so only *other* members are
notified; image-only and `updated_at`-only expense updates produce nothing,
which is what stops a second feed row appearing when an expense is created with
photos; personal groups and deleted groups produce nothing. Copy is the group
name as title and `{expense title} - {cost}` as body, with localized `Edit` /
`Deleted` prefixes, localized per recipient locale (en/ar, fallback en). Full
contract in [BACKEND_BEHAVIOUR.md](BACKEND_BEHAVIOUR.md).

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
- receipt AI: `receipt_scan_mode` (off/local/nano/cloud), cloud provider, and BYO API keys

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
- Invite links use the web app domain when the backend supplies one. On deploy, `/invite-redirect` (and the legacy `/functions/v1/invite-redirect`) is served by **Firebase Hosting** via a rewrite to static `invite-redirect.html`, built from `web/invite-redirect-template.html` with `__CLOUD_INVITE_RESOLVER_URL__` substituted at build time. That page redirects to the backend's invite resolver, which validates the token and redirects the user to `redirect.html`. This needs only static hosting. When the user is already inside the web app, the same path is handled by GoRouter, which redirects to `cloudBackend.invites.resolverUrlFor(token)`.
- Invite redirect static page: `web/redirect.html`
  - desktop -> web invite route
  - mobile -> attempts app deep link with timed web fallback
- Invite/OG assets: `web/invite-redirect-template.html`, `web/og-invite.png`. The template carries a `__CLOUD_INVITE_RESOLVER_URL__` placeholder that the build substitutes with the backend's invite resolver endpoint.
- Public privacy page: `web/privacy/index.html`
- Account deletion is described in `docs/DELETE_ACCOUNT.md`; the in-app options are Delete local data and Delete cloud data under Settings > Advanced (and a public page at `web/delete-account/index.html` when deployed).
- Deployment cache control is configured in `firebase.json`: entry scripts/manifest/SW/invite HTML + catch-all `**` use `max-age=0, must-revalidate` (Firebase matches header `source` on the **request path before rewrites**; default HTML cache is one hour). Hosting deploys via GitHub Actions tag releases.

## Backend contract

No backend lives in this repository. What lives here is the interface one must
satisfy: `packages/hisab_backend` declares nine facets (`auth`, `sync`,
`groups`, `invites`, `notifications`, `files`, `account`, `telemetry`,
`health`), and `packages/hisab_cloud` is a stub that registers nothing, which is
why a default build is local-only.

Everything in `lib/` reaches the network through `cloudBackend`, and gates on
`cloudAvailable`. Adding a direct HTTP or vendor SDK call to `lib/` breaks the
offline build and CI will catch it.

The app expects the server to own these tables — `groups`, `group_members`,
`participants`, `expenses`, `expense_tags`, `group_invites`, `invite_usages`,
`telemetry`, `device_tokens`, `user_notifications` — and to enforce
authorization there rather than trusting the client. Membership changes, invite
acceptance and account deletion are server-authorized operations behind the
`groups`, `invites` and `account` facets, not table writes.

- Contract reference: [`packages/hisab_backend/README.md`](../packages/hisab_backend/README.md)
- Behaviour the client assumes: [BACKEND_BEHAVIOUR.md](BACKEND_BEHAVIOUR.md)
- Building your own: [SELF_HOSTING.md](SELF_HOSTING.md)

## MCP available in the IDE

MCP servers enabled in Cursor vary by machine/workspace. Common ones for this project:

| Area | Typical server ids | Purpose |
|------|-------------------|--------|
| **Firebase** | `plugin-firebase-firebase` / `user-firebase` | FCM, Hosting, Auth, docs |
| **Browser** | `cursor-ide-browser` | Web automation / screenshots |
| **Mobile debug** | `user-polyscreen`, `user-Mobile MCP` | Device install, UI snapshot, crashes (Hisab Debug) |
| **App control** | `cursor-app-control` | Workspace / project helpers |

Discover live tools with MCP catalog/`GetMcpTools` rather than hard-coding server names — ids drift between Cursor versions.

### How to use Firebase MCP

The Firebase MCP server is configured in `.cursor/mcp.json` as `firebase` (command: `npx -y firebase-tools@latest mcp`). When Cursor loads it for this project, the **server identifier** may be `project-0-hisab-firebase` — use that name when calling Firebase MCP tools (e.g. from the AI or from scripts that invoke MCP).

1. **Auth and project**  
   Many tools require the user to be signed in (`npx firebase-tools login`) and a Firebase project to be set. The server uses the same credentials as the Firebase CLI in the environment where Cursor runs.

2. **Sending a push notification**  
   Use the `messaging_send_message` tool with:
   - `registration_token`: FCM device token (from app registration, or from your backend's device token table)
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

Build-time config the client itself reads (`lib/core/constants/firebase_config.dart` and `lib/main.dart`):

- `FIREBASE_*` (web SDK options, FCM only)
- `FCM_VAPID_KEY` (web push)
- `ENABLE_WEB_SEMANTICS` (web accessibility semantics, off by default)

A backend package defines its own flags on top of these; the client neither reads nor validates them.

Non-secret app constants (e.g. `reportIssueUrl`) live in `lib/core/constants/app_config.dart`. Anything else comes from `--dart-define` or gitignored define files — see `docs/CONFIGURATION.md`. With no backend registered the app runs local-only by design: no environment variable is required, and it must not crash or throw.

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
- custom URL scheme `com.shenepoy.hisab` (legacy `io.supabase.hisab` still registered)

## CI/CD

`.github/workflows/ci.yml` — every push and pull request:

- static gates (`scripts/verify_security.sh`, `scripts/verify_infra.sh`)
- unit and widget tests, plus integration tests on web (Chrome)
- **offline build guard**: `scripts/ci/assert_offline_only.sh` and a `foss` build, which fail if a backend dependency or a tracked credential enters the tree

`.github/workflows/release.yml` — on `v*` tags:

- the same checks, then `scripts/ci/build_android.sh foss`
- per-ABI signed APKs attached to a **draft** GitHub Release

The release is left as a draft because the private cloud pipeline attaches its
own artifacts to the same release afterwards. Neither workflow has access to
production credentials; the only secrets involved are the FOSS signing key.

Every CI step is a one-line call into `scripts/ci/`, so the same command that
runs in Actions runs locally. Agent pre-release gate:
[`.cursor/skills/hisab-release-checks/SKILL.md`](../.cursor/skills/hisab-release-checks/SKILL.md).
Local: `bash ./scripts/run_release_checks.sh`.

## Key Dependencies (Selected)

- state: `flutter_riverpod`, `riverpod_annotation`
- navigation: `go_router`
- **Git deps:** `flutter_logging_service` (siglat), `flutter_settings_framework` (edadat) — pinned to `ref: main` in pubspec for CI; local path override (lock not committed) is used for fast iteration on those packages. Optional: publish to pub.dev or vendor into this repo for long-term reproducibility.
- local db/sync engine: `powersync`
- backend contract: `hisab_backend` (interfaces only); implementation supplied by `hisab_cloud`
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
  - **Unit:** domain, settle-up, sync error classification, backup parse, translations, receipt local extractor / OCR fixtures (`test/fixtures/receipts/`, `test/fixtures/receipts/ocr_raw/`).
  - **Widget:** Public custom widgets under `test/` mirroring `lib/`: `test/core/` (async_value_builder, back_button_keyboard_dismiss, connection_banner, currency_picker_list, expandable_section, floating_nav_bar, invite_link_handler, pwa_install_banner, pwa_capabilities, sync_status_chip), `test/groups/` (group_card, create_invite_sheet), `test/expenses/` (expense_list_tile, expense_title_section, expense_amount_section, expense_split_section, expense_bill_breakdown_section, expense_detail_body, expense_detail_body_header), `test/settings/` (logs_viewer_dialog, privacy_policy_page), `test/pages/` (main_scaffold, home_page, archived_groups_page), `test/balance/` (balance_list: settlement permission — owner vs member/debtor), `test/onboarding/` (onboarding_page), plus error_content. Widget tests use EasyLocalization + MaterialApp; Riverpod widgets use ProviderScope with overrides when needed. See [test/widget_test_helpers.dart](../test/widget_test_helpers.dart) and [test/README.md](../test/README.md).
  - **Locale:** Key widgets are tested in both English and Arabic via `test/widget_test_helpers.dart`: `pumpApp(tester, child: ..., locale: Locale('ar'))` and `testSupportedLocales`. Edge cases (empty/zero/long content, optional params) are covered where relevant. Translation file parity, Dart key usage, and Arabic glossary: `test/translations_test.dart` (see [I18N.md](I18N.md)).
  - **Integration-style:** Local PowerSync DB, sync engine with fake backend. See [test/README.md](../test/README.md) for PowerSync native binary requirements and coverage (`flutter test --coverage`).
  - **Integration (local-only):** Full-app flows in `integration_test/` — smoke, onboarding, group, personal, expense (tags, photos, currencies, bill breakdown), balance (settlements, freeze), settings. Run with `flutter drive` on web or `flutter test integration_test/ -d <device>`. See [test/README.md](../test/README.md).
  - **Cloud paths:** covered with `test/support/fake_cloud.dart`, an in-memory implementation of every `CloudBackend` facet, so repository and provider tests exercise online behaviour without a server. End-to-end tests against a live backend live with that backend — see [test/README.md](../test/README.md).
- **Widget test helper:** `test/widget_test_helpers.dart` provides `pumpApp(tester, child, locale?, pumpAndSettle?)` to wrap the widget in EasyLocalization + MaterialApp; use for presentational widgets. For widgets that depend on Riverpod, build ProviderScope + EasyLocalization + MaterialApp inline with overrides (see e.g. `test/balance/balance_list_widget_test.dart`).
- **Generated code:** Run `flutter pub run build_runner build --delete-conflicting-outputs` (or `watch`) to regenerate `.g.dart` files before running tests or when changing providers/settings.

## Development

- **Codegen:** Use `flutter pub run build_runner build --delete-conflicting-outputs` after changing Riverpod providers, settings, or other annotated code so `.g.dart` files stay in sync.
- **Tooling:** Prefer available MCP servers (see “MCP available in the IDE” above) for schema checks, device debug, and browser automation when they are enabled in the workspace.

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
- **CODEBASE doc:** This overview was updated to reflect current lib layout (core subdirs, domain barrel, repositories), SyncEngine/SyncBackend, core services/widgets/receipt, feature details, the backend contract, web assets, and test layout.
- **Modal centering (web tablet/desktop):** Modals are centered in the full viewport by default (`centerInFullViewport` defaults to true). `showResponsiveSheet` and `showAppDialog` support `centerInFullViewport`; pass `false` for modals opened from home/settings that should stay in the content area next to the rail. The app builder uses `Positioned.fill` so the root navigator gets full viewport size. See `docs/MODAL_CENTERING_AND_RESPONSIVE_SHEET.md`.
- **App bar title aligned with content:** All pages with a constrained body use **ContentAlignedAppBar** so the app bar title sits in the same horizontal band as the body (same `contentBandMetrics` as `ConstrainedContent`). The title is absolutely positioned in the app bar so it is not affected by leading/actions; titles are not shrunk with `FittedBox` (use ellipsis / elision in the title widget). Wrap the scaffold in `LayoutBuilder` and pass `layoutConstraints.maxWidth` as `contentAreaWidth`. See `lib/core/layout/content_aligned_app_bar.dart` and the “Layout (core/layout)” section above.

- **Settlement permission:** By default only the group owner or the debtor (participant who owes) can record a settlement. Group setting **Members can record settlements for others** (`Group.allowMemberSettleForOthers`, default false) allows any member to record. Schema: `groups.allow_member_settle_for_others`. **Client + server:** Balance list / record sheet enforce the rule offline, and a backend is expected to enforce the same rule plus freeze-blocks-insert and archive-blocks-mutations server side (see [BACKEND_BEHAVIOUR.md](BACKEND_BEHAVIOUR.md)). See `lib/features/balance/widgets/balance_list.dart`, `lib/features/groups/pages/group_settings_page.dart`, `lib/domain/group.dart`.
- **Settlement titles (i18n):** Transfer rows keep a human `Expense.title` for push/activity feeds, but list/detail/share rebuild the title at display time via `expenseDisplayTitle` / `expenseDisplayTitleFromMap` (`lib/core/utils/expense_display_title.dart`) so EN/AR follow the current locale.
- **Frozen snapshot corrupt:** If `settlement_snapshot_json` fails to parse while frozen (and is not the archive auto-freeze marker), Balance shows a corrupt banner and empty balances instead of silently recomputing live numbers (`GroupBalanceResult.snapshotCorrupt`).
- **Online integration tests:** End-to-end auth, sync and invite tests need a real backend, so they live with the backend rather than here. This repository's suite is unit, widget and offline integration only, and runs with no services present. See [test/README.md](../test/README.md).
- **Never-expiring invites:** a null expiry is valid, not expired. Both the client and any backend must treat `expires_at IS NULL` as "no expiry" rather than comparing against it.
- **Duplicate participant guard:** memberships are unique per (group, user), and at most one active linked participant may exist per user per group. Invite acceptance is expected to reuse an existing participant, or claim an unlinked placeholder, rather than create a second row. Details in [BACKEND_BEHAVIOUR.md](BACKEND_BEHAVIOUR.md).
- **i18n hardcode pass:** User-facing strings (scanner, notifications channel/fallbacks, language/theme labels, exchange-rate label, receipt/status defaults, relative times, feedback issue title, etc.) go through translation keys in both `en.json` and `ar.json`. Built-in scanner pattern names are stored as keys and shown via `scannerPatternDisplayName`. Conventions and intentional exceptions: [I18N.md](I18N.md).

## Related Docs

- `docs/MODAL_CENTERING_AND_RESPONSIVE_SHEET.md` - modal/dialog centering on web, `centerInFullViewport`, and responsive sheet API
- `docs/SELF_HOSTING.md` - implement the backend contract against your own server
- `docs/BACKEND_BEHAVIOUR.md` - server-side rules the client relies on
- `packages/hisab_backend/README.md` - facet-by-facet contract reference
- `docs/PERSONAL_FEATURE.md` - personal (my-expenses-only) mode: data model, flows, code locations, backup, i18n
- `docs/TRANSACTION_SCANNER.md` - Android notification → draft → personal expense scanner
- `docs/I18N.md` - localization conventions, key groups, en/ar parity, notification/scanner special cases
- `docs/CONFIGURATION.md` - runtime configuration quick reference
- `docs/RELEASE_SETUP.md` and `docs/PLAY_CONSOLE_DECLARATIONS.md` - release/distribution notes
- `docs/DELETE_ACCOUNT.md` - user-facing guide for deleting data and requesting account deletion
- `test/README.md` - comprehensive test documentation: unit, widget, integration (local + online), coverage
