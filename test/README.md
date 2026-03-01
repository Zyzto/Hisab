# Hisab tests

## Running tests

Run the full suite:

```bash
flutter test
```

Run a single file:

```bash
flutter test test/settle_up_service_test.dart
```

## Run all tests (runner)

A cross-platform Dart runner runs unit/widget tests, then in parallel: Android integration (with optional AVD launch) and web integration (ChromeDriver + `flutter drive`), and prints a summary with log paths.

**From repo root (all platforms):**

```bash
dart run tool/run_all_tests.dart
```

Optional wrappers: `./scripts/run_all_tests.sh` (Linux/macOS) or `scripts\run_all_tests.bat` (Windows).

**Options:** `--skip-unit` (skip unit & widget tests), `--skip-android`, `--skip-web`, `--no-avd` (do not launch an emulator; fail if no Android device is present).

**Logs:** Written to `logs/test_run_<timestamp>/` (e.g. `unit_widget.log`, `integration_android.log`, `integration_web.log`). The summary table and any error log paths are printed at the end.

**Prerequisites:** Flutter SDK, Dart SDK. For Android: a device or AVD (runner can launch the first available emulator). For web: Chrome and ChromeDriver on PATH (version-matched); set `CHROME_EXECUTABLE` if Chrome is not in the default location.

## Widget tests

- **Layout:** Test directories mirror `lib/`: `test/core/`, `test/groups/`, `test/expenses/`, `test/settings/`, `test/pages/`, plus `test/balance/`, `test/` (app, error content, etc.).
- **Helper:** `test/widget_test_helpers.dart` provides:
  - `pumpApp(tester, child: widget, locale: Locale('en')|Locale('ar'), pumpAndSettle: true)` — wraps the widget in EasyLocalization + MaterialApp + Scaffold, then pumps. Use for presentational widgets that do not need Riverpod.
  - `testSupportedLocales` — `[Locale('en'), Locale('ar')]` for use when building EasyLocalization manually (e.g. with ProviderScope overrides).
- **Conventions:** Use `setUpAll` to disable Easy Localization build logging (`EasyLocalization.logger.enableBuildModes = []`). For widgets that depend on providers, wrap in `ProviderScope(overrides: [...])` then EasyLocalization then MaterialApp (see e.g. `test/balance/balance_list_widget_test.dart`, `test/core/sync_status_chip_widget_test.dart`). The balance list test overrides `myMemberInGroupProvider` and `myRoleInGroupProvider` to assert both owner (record enabled) and member-not-debtor (record disabled) behaviour.
- **Locale:** Key widgets have at least one test with `locale: Locale('ar')` (via `pumpApp` or manual `startLocale: Locale('ar')`) to ensure RTL/translations work.
- **Edge cases:** Tests cover empty/zero/long content and optional parameters where relevant (e.g. GroupCard empty name, personal group, pin; ExpenseListTile zero amount, long title, income type; ExpandableSection empty `trailingSummary`).

## Schema alignment

`test/schema_alignment_test.dart` asserts that synced table columns match between `lib/core/database/powersync_schema.dart` and the INSERT column lists in `lib/core/database/sync_engine.dart`. It runs with `flutter test` and fails the build on mismatch. See `docs/CODEBASE.md` "Schema alignment".

## PowerSync

Tests in `local_database_test.dart`, `sync_test.dart`, and `supabase_repository_test.dart` depend on the PowerSync native binary. On first run they probe for availability (e.g. by initializing a temporary database). If the binary cannot be loaded (e.g. in some CI environments or when the platform is unsupported), those tests are skipped; the rest of the suite still runs.

## Integration tests

Full-app integration tests live in `integration_test/`. They run the real UI (App + GoRouter + providers) with a temp PowerSync DB and no live Supabase/Firebase (local-only).

**Platforms:** Integration tests target the **web app** (Chrome). CI runs them with `flutter drive` and `-d chrome`. You can also run on Android or iOS when a device/emulator is available.

Run on web — primary target (requires ChromeDriver on port **4444**; Flutter does not expose a flag to use another port):

```bash
# Terminal 1: set Chrome path (so ChromeDriver can launch Chrome) and start ChromeDriver
export CHROME_EXECUTABLE=/usr/bin/google-chrome-stable
chromedriver --port=4444

# Terminal 2: run the integration tests (--release avoids "Waiting for connection from debug service" hang)
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d web-server \
  --release \
  --web-browser-flag=--no-sandbox
```

**If it hangs on "Waiting for connection from debug service":** use `--release` as above (no debug service in release mode). Also set `CHROME_EXECUTABLE` in **Terminal 1** before starting ChromeDriver so it can launch Chrome when Flutter connects.

**If you get `SessionNotCreatedException`:** ChromeDriver could not create a browser session. Try:

1. **Match versions** — Chrome and ChromeDriver major version must match (e.g. Chrome 131 → ChromeDriver 131.x). Check with:
   ```bash
   /usr/bin/google-chrome-stable --version
   chromedriver --version
   ```
2. **Set Chrome in the ChromeDriver terminal** — In **Terminal 1** (where you run `chromedriver`), run:
   ```bash
   export CHROME_EXECUTABLE=/usr/bin/google-chrome-stable
   chromedriver --port=4444
   ```
3. **See ChromeDriver's error** — Restart ChromeDriver with verbose logging to see why the session failed:
   ```bash
   chromedriver --port=4444 --verbose
   ```
   Then run `flutter drive ...` again; the ChromeDriver terminal will show the real error (e.g. "Chrome failed to start", version mismatch, or missing library).

**Installing ChromeDriver (Linux)** — the driver version must match your Chrome version:

1. **Get your Chrome version:**
   ```bash
   /usr/bin/google-chrome-stable --version
   ```
   Example output: `Google Chrome 131.0.6778.69` → you need ChromeDriver **131.x**.

2. **Download matching ChromeDriver** from [Chrome for Testing](https://googlechromelabs.github.io/chrome-for-testing/):
   - Open the [downloads list](https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json) or the [web](https://googlechromelabs.github.io/chrome-for-testing/) and pick the **Stable** build whose major version matches (e.g. 131).
   - Download **chromedriver-linux64.zip** for that version, unzip it, and put the `chromedriver` binary in your `PATH` (e.g. `~/bin` or `/usr/local/bin`):
   ```bash
   unzip chromedriver-linux64.zip
   chmod +x chromedriver
   mv chromedriver ~/bin/   # or sudo mv chromedriver /usr/local/bin/
   ```

3. **Point tests at Chrome** (if needed):
   ```bash
   export CHROME_EXECUTABLE=/usr/bin/google-chrome-stable
   ```

Run on Android when an emulator or device is available:

```bash
flutter devices   # list devices
flutter test integration_test/ -d <android_device_id>
```

Run on iOS when a simulator or device is available:

```bash
flutter test integration_test/ -d <ios_device_id>
```

**Android emulator troubleshooting**

- **`VmServiceDisappearedException`**, **`registerService: (-32000) Service connection disposed`**, or **`ext.flutter.driver: (112) Service has disappeared`** — The test driver lost the VM service connection to the app (often during "loading" or mid-run). This is emulator/connection instability, not test code. When using `dart run tool/run_all_tests.dart`, the runner continues to the web phase after Android fails; the **Stage Log** printed at the end is from the **web** run, not Android. **Workaround — use `flutter drive`** for Android (the runner uses this with `--android-drive`):
  ```bash
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/app_test.dart \
    -d emulator-5554
  ```
  Or with the full runner: `dart run tool/run_all_tests.dart --android-drive`. Other options: (1) Cold boot the emulator (AVD Manager → Cold Boot Now) and retry. (2) Use a real device if available. (3) Reduce emulator load (Developer options → disable animations). (4) Update Flutter (`flutter upgrade`).
- **`adb: device offline`** — Restart the emulator and/or run `adb kill-server` then `adb start-server`. Ensure the emulator has enough RAM and disk.
- **`INSTALL_FAILED_INSUFFICIENT_STORAGE`** — Free space on the emulator (e.g. wipe data or use a larger virtual disk).

**File structure:**

```
integration_test/
  helpers/
    test_bootstrap.dart          -- local-only bootstrap (temp DB, settings, runApp)
    online_test_bootstrap.dart   -- online bootstrap (Supabase init, sign-in, runApp)
    test_helpers.dart            -- reusable finders, tap helpers, wait helpers
    fake_image_picker.dart       -- mock ImagePickerPlatform for photo tests
    test_db_path.dart            -- platform-conditional DB path (io/stub)
  smoke_test.dart                -- app opens, home visible, nav works
  onboarding_test.dart           -- full 4-page onboarding flow (Welcome → Preferences → Permissions → Connect)
  group_flows_test.dart          -- create group, detail tabs, settings, archive
  personal_test.dart             -- create personal budget, simplified UI, add expense
  expense_flows_test.dart        -- add/edit/view expenses, all split types, income/transfer
  balance_test.dart              -- verify balances, record settlement
  settings_test.dart             -- theme, language, font size, telemetry toggle
  app_test.dart                  -- barrel that imports all local-only test files
  online/
    auth_online_test.dart        -- sign-in, sign-out, session verification
    sync_online_test.dart        -- create group/expense via UI, verify in Supabase DB
    invite_online_test.dart      -- 2-user invite flow (create, accept, verify membership)
  online_app_test.dart           -- barrel that imports all online test files
test_driver/
  integration_test.dart          -- web driver entry point (custom diagnostics)
tool/
  run_all_tests.dart            -- cross-platform runner: unit/widget, then Android + web integration, summary
  run_online_tests.dart         -- cross-platform online test runner (Supabase, ChromeDriver, cleanup)
scripts/
  run_all_tests.sh, run_all_tests.bat  -- wrappers for dart run tool/run_all_tests.dart
  run_online_tests.sh           -- wrapper for dart run tool/run_online_tests.dart (Linux/macOS)
```

- **Bootstrap (local):** `integration_test/helpers/test_bootstrap.dart` initializes EasyLocalization, a temp PowerSync DB, and settings (onboarding completed, local-only), then calls `runApp(...)` with the same overrides as production. No Supabase/Firebase or LoggingService. Set `skipOnboarding: false` to exercise the onboarding flow.
- **Bootstrap (online):** `integration_test/helpers/online_test_bootstrap.dart` initializes Supabase with local credentials (via `--dart-define`), sets `localOnlySettingDef` to `false`, optionally signs in a test user, and runs the app in online mode. Provides `signInAs()`, `signOutCurrentUser()`, and the test user constants (`testUserAEmail`, `testUserBEmail`, `testPassword`).
- **Helpers:** `integration_test/helpers/test_helpers.dart` provides `pumpAndSettleWithTimeout`, `tapAndSettle`, `enterTextAndPump` (with web fallback), `waitForWidget`, `scrollUntilVisible`, `tapSubmitExpenseButton`, `ensureFormClosed`, `stage` (stage-based progress recording), and `ensureBootstrapReady`.
- **Test flows — local-only mode** (`app_test.dart`):
  - **Smoke:** App opens to home (Groups/Personal/FAB visible); navigate to Settings and back.
  - **Onboarding:** Complete all 4 pages (Welcome → Preferences → Permissions → Connect) and land on home.
  - **Group flows:** Create group with participants (Alice, Bob) → verify detail tabs (Expenses/Balance/People) → open group settings → change icon/color/currency/settlement → archive group.
  - **Personal:** Create personal budget → verify simplified UI (no Balance/People tabs) → add expense.
  - **Expense flows:** Create group with 2 participants → add expenses with tags, description, bill breakdown, long titles, currency change, exchange rates → all split types → photo attachment (skipped on web) → view detail → edit expense → add Income and Transfer.
  - **Balance:** Create group, add expense → switch to Balance tab → verify balances and settlement suggestions → record and freeze settlements. The test user is the group owner, so they can record any settlement (by default only the owner or the debtor can record; see group setting "Members can record settlements for others").
  - **Settings:** Change theme, language (Arabic and back), font size, toggle telemetry; verify settings persist across navigation.
- **Test flows — online mode** (`online_app_test.dart`, requires local Supabase):
  - **Auth:** Sign in as User A → verify session → navigate to Settings → sign out → programmatic re-sign-in → sign in as User B.
  - **Sync:** Sign in → create group via UI → verify group exists in Supabase DB → add expense → verify expense synced → delete group via UI → verify deletion propagated.
  - **Invite:** User A creates group → creates invite token (RPC) → signs out → User B accepts invite (RPC) → verify membership → User A verifies member list → cleanup.
- **Requirements:** For web, Chrome/Chromium must be installed (set `CHROME_EXECUTABLE` if needed). PowerSync is used; on web it uses the web-backed storage. If the bootstrap fails (e.g. PowerSync unavailable), tests fail with a clear message.
- **CI:** Runs local integration tests on **web** (`flutter drive` with `-d chrome`). Online tests run separately with a Docker-based Supabase instance. For Android/iOS, use an emulator or Firebase Test Lab.

## Online integration tests (local Supabase)

Online integration tests run the app against a **local Supabase instance** via Docker. They cover authentication, data sync, and multi-user invite flows — all without touching production.

### Prerequisites

| Requirement | Check |
|---|---|
| Docker | `docker info` (must be running) |
| Supabase CLI | `supabase --version` (install: `npm i -g supabase` or [docs](https://supabase.com/docs/guides/cli/getting-started)) |
| Chrome + ChromeDriver (web) | Same as local integration tests (version-matched); only needed for web |

### Quick start (one command)

**Recommended — cross-platform Dart runner (all platforms):**

```bash
dart run tool/run_online_tests.dart
```

Optional: `dart run tool/run_online_tests.dart android` to run on a connected Android device. On Linux/macOS you can use the shell wrapper: `./scripts/run_online_tests.sh` or `./scripts/run_online_tests.sh android`.

The runner:
1. Checks prerequisites (Docker, Supabase CLI, ChromeDriver for web)
2. Starts local Supabase (`supabase start`) and resets the database (migrations + seed)
3. Parses credentials from `supabase status --output json` (no `jq` required)
4. For web: starts ChromeDriver on port 4444 if needed, then runs `flutter drive` with the online test barrel
5. Stops Supabase and ChromeDriver (if started) on exit, including on interrupt (e.g. Ctrl+C)
6. Writes all output to `logs/online_tests_<timestamp>.log` and prints "Online tests: PASS" or "Online tests: FAILED (see log: ...)"

### Manual steps (step by step)

```bash
# 1. Start local Supabase (first run pulls Docker images — takes a few minutes)
supabase start

# 2. Reset DB to apply all migrations + seed test users
supabase db reset

# 3. Extract credentials
SUPABASE_URL=$(supabase status --output json | jq -r '.API_URL')
SUPABASE_ANON_KEY=$(supabase status --output json | jq -r '.ANON_KEY')

# 4. Run online integration tests on web
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/online_app_test.dart \
  -d web-server --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --web-browser-flag=--no-sandbox

# 5. Stop Supabase when done
supabase stop
```

### Local Supabase configuration

All configuration lives under `supabase/`:

| File | Purpose |
|---|---|
| `supabase/config.toml` | Supabase project config: ports, auth settings, storage buckets, rate limits |
| `supabase/migrations/20250101000001_*.sql` – `…000019_*.sql` | 19 ordered migrations covering schema, RLS, RPCs, indexes, and features |
| `supabase/seed.sql` | Seeds two test users into `auth.users` + `auth.identities` |

**Test users** (seeded automatically by `supabase db reset`):

| User | Email | Password | UUID |
|---|---|---|---|
| User A | `test-a@hisab.test` | `TestPass123!` | `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa` |
| User B | `test-b@hisab.test` | `TestPass123!` | `bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb` |

**Key `config.toml` settings for testing:**
- `auth.email.enable_confirmations = false` — emails auto-confirmed (no verification needed)
- `auth.email.double_confirm_changes = false` — no dual confirmation for email changes
- `auth.email.max_frequency = "0s"` — no cooldown between email sends
- `auth.rate_limit.*` = `1000` — high limits to prevent throttling during test runs
- `storage.buckets.receipt-images` — pre-created bucket for receipt image uploads

**Migrations:** The 19 migration files consolidate the complete Supabase schema from `docs/SUPABASE_SETUP.md`:

1. `core_schema` — tables (groups, participants, expenses, etc.)
2. `rls_policies` — row-level security
3. `rpc_functions` — invite, ownership, member management RPCs
4. `security_hardening` — column permissions, function security
5. `device_tokens` — FCM token storage
6. `device_tokens_locale` — locale column for localized push
7. `schema_additions` — additional indexes, columns
8. `rpc_invites_extended` — extended invite RPCs
9. `revoke_toggle_rpcs` — revoke/toggle functions
10. `rls_performance` — RLS policy optimization
11. `indexes` — performance indexes
12. `groups_archive` — archive support
13. `merge_participant` — participant merge RPC
14. `participants_left` — left_at tracking
15. `receipt_images_bucket` — storage bucket + policies
16. `groups_personal_budget` — personal budget columns
17. `anonymize_on_delete` — name anonymization on account delete
18. `receipt_image_paths` — receipt image path columns
19. `groups_allow_member_settle_for_others` — settlement permission (owner or debtor only by default)

> **Note:** Migration 6 from the original setup (pg_net notification triggers) is intentionally skipped — `pg_net` is not available in the local Supabase environment.

### Online test suites

| Suite | File | What it tests |
|---|---|---|
| **Auth** | `integration_test/online/auth_online_test.dart` | Sign in User A → verify session → navigate to Settings → sign out → re-sign-in → sign in User B |
| **Sync** | `integration_test/online/sync_online_test.dart` | Create group via UI → verify in Supabase DB → add expense → verify synced → delete group → verify removed |
| **Invite** | `integration_test/online/invite_online_test.dart` | User A creates group + invite token → User B accepts → verify membership → User A verifies member list |

### CI (GitHub Actions)

The `test-online` job in `.github/workflows/release.yml` runs online tests automatically:
1. Sets up Flutter and Supabase CLI
2. Starts local Supabase (Docker is available on `ubuntu-latest`)
3. Resets the database
4. Extracts credentials
5. Runs `flutter drive` with the online test barrel
6. Stops Supabase in an `always()` cleanup step

No additional GitHub secrets are needed — the local Supabase instance generates its own URL and anon key.

### Troubleshooting

| Issue | Fix |
|---|---|
| `supabase start` hangs | Ensure Docker is running (`docker info`). First run pulls ~2 GB of images. |
| `ERROR: Could not get SUPABASE_URL` | Supabase didn't start. Check `docker ps` and `supabase status`. |
| Auth sign-in fails in test | Run `supabase db reset` to re-seed test users. |
| `pg_net` extension error | Expected — migration 6 (notification triggers) is skipped locally. |
| Rate limit hit during tests | Check `config.toml` rate limits are set to 1000. |
| Test passes locally but fails in CI | CI uses `--no-sandbox` and `--disable-dev-shm-usage` flags for headless Chrome. |

## Coverage

To generate a coverage report:

```bash
flutter test --coverage
```

View the report (e.g. with `lcov`):

```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```
