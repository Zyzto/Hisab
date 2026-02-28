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

## Widget tests

- **Layout:** Test directories mirror `lib/`: `test/core/`, `test/groups/`, `test/expenses/`, `test/settings/`, `test/pages/`, plus `test/balance/`, `test/` (app, error content, etc.).
- **Helper:** `test/widget_test_helpers.dart` provides:
  - `pumpApp(tester, child: widget, locale: Locale('en')|Locale('ar'), pumpAndSettle: true)` — wraps the widget in EasyLocalization + MaterialApp + Scaffold, then pumps. Use for presentational widgets that do not need Riverpod.
  - `testSupportedLocales` — `[Locale('en'), Locale('ar')]` for use when building EasyLocalization manually (e.g. with ProviderScope overrides).
- **Conventions:** Use `setUpAll` to disable Easy Localization build logging (`EasyLocalization.logger.enableBuildModes = []`). For widgets that depend on providers, wrap in `ProviderScope(overrides: [...])` then EasyLocalization then MaterialApp (see e.g. `test/balance/balance_list_widget_test.dart`, `test/core/sync_status_chip_widget_test.dart`).
- **Locale:** Key widgets have at least one test with `locale: Locale('ar')` (via `pumpApp` or manual `startLocale: Locale('ar')`) to ensure RTL/translations work.
- **Edge cases:** Tests cover empty/zero/long content and optional parameters where relevant (e.g. GroupCard empty name, personal group, pin; ExpenseListTile zero amount, long title, income type; ExpandableSection empty `trailingSummary`).

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
  onboarding_test.dart           -- full 3-page onboarding flow
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
scripts/
  run_online_tests.sh            -- one-command online test runner (starts Supabase, runs tests)
```

- **Bootstrap (local):** `integration_test/helpers/test_bootstrap.dart` initializes EasyLocalization, a temp PowerSync DB, and settings (onboarding completed, local-only), then calls `runApp(...)` with the same overrides as production. No Supabase/Firebase or LoggingService. Set `skipOnboarding: false` to exercise the onboarding flow.
- **Bootstrap (online):** `integration_test/helpers/online_test_bootstrap.dart` initializes Supabase with local credentials (via `--dart-define`), sets `localOnlySettingDef` to `false`, optionally signs in a test user, and runs the app in online mode. Provides `signInAs()`, `signOutCurrentUser()`, and the test user constants (`testUserAEmail`, `testUserBEmail`, `testPassword`).
- **Helpers:** `integration_test/helpers/test_helpers.dart` provides `pumpAndSettleWithTimeout`, `tapAndSettle`, `enterTextAndPump` (with web fallback), `waitForWidget`, `scrollUntilVisible`, `tapSubmitExpenseButton`, `ensureFormClosed`, `stage` (stage-based progress recording), and `ensureBootstrapReady`.
- **Test flows — local-only mode** (`app_test.dart`):
  - **Smoke:** App opens to home (Groups/Personal/FAB visible); navigate to Settings and back.
  - **Onboarding:** Complete all 3 pages (Welcome → Permissions → Connect) and land on home.
  - **Group flows:** Create group with participants (Alice, Bob) → verify detail tabs (Expenses/Balance/People) → open group settings → change icon/color/currency/settlement → archive group.
  - **Personal:** Create personal budget → verify simplified UI (no Balance/People tabs) → add expense.
  - **Expense flows:** Create group with 2 participants → add expenses with tags, description, bill breakdown, long titles, currency change, exchange rates → all split types → photo attachment (skipped on web) → view detail → edit expense → add Income and Transfer.
  - **Balance:** Create group, add expense → switch to Balance tab → verify balances and settlement suggestions → record and freeze settlements.
  - **Settings:** Change theme, language (Arabic and back), font size, toggle telemetry; verify settings persist across navigation.
- **Test flows — online mode** (`online_app_test.dart`, requires local Supabase):
  - **Auth:** Sign in as User A → verify session → navigate to Settings → sign out → programmatic re-sign-in → sign in as User B.
  - **Sync:** Sign in → create group via UI → verify group exists in Supabase DB → add expense → verify expense synced → delete group via UI → verify deletion propagated.
  - **Invite:** User A creates group → creates invite token (RPC) → signs out → User B accepts invite (RPC) → verify membership → User A verifies member list → cleanup.
- **Requirements:** For web, Chrome/Chromium must be installed (set `CHROME_EXECUTABLE` if needed). PowerSync is used; on web it uses the web-backed storage. If the bootstrap fails (e.g. PowerSync unavailable), tests fail with a clear message.
- **CI:** Runs local integration tests on **web** (`flutter drive` with `-d chrome`). Online tests run separately with a Docker-based Supabase instance. For Android/iOS, use an emulator or Firebase Test Lab.

## Maestro E2E

[Maestro](https://maestro.dev) provides YAML-based E2E flows that run alongside the Flutter integration tests. The project targets the **web** app first (no iOS/Android required).

**Prerequisite:** The Flutter web app must already be running. Maestro only opens a browser to the flow URL and drives the UI; it does not start the app. If the app is not running, flows will fail (e.g. "Settings" is visible assertion fails). If you see a **white page** in the browser, run the app with `--release` (see step 1 below) so it does not wait for the debug service.

**Install Maestro CLI:** See [maestro.dev](https://maestro.dev) (e.g. `curl -Ls "https://get.maestro.mobile.dev" | bash`). Optionally install Maestro Studio for visual authoring and recording.

**Run flows (web):**

1. Start the Flutter web app on port 9090 (flows use `http://localhost:9090`). Use **release** mode so the app renders immediately (debug mode waits for the debug service and can show a white screen). Keep it running:
   ```bash
   flutter run -d web-server --web-port=9090 --release
   ```
2. In another terminal, from the repo root:
   ```bash
   maestro test .maestro/
   ```
   Maestro opens a browser to the URL and runs the flows. To use a different URL (e.g. deployed staging), pass env: `maestro test .maestro/ --env MAESTRO_WEB_URL=https://your-app.web.app` (and set `url` in the flow config to `${MAESTRO_WEB_URL}` if your Maestro version supports it), or edit the `url` in each YAML file under `.maestro/`.

**Flows:** Both flows assume **first launch** (onboarding is shown). They complete onboarding (Next → Next → Start with Offline) then run the test. If you have already completed onboarding in the browser, clear the site's storage (e.g. Application → Storage → Clear site data) so onboarding appears again, or run in an incognito window.

- **smoke.yaml** — Launch → complete onboarding → assert home (Settings and Create Group FAB visible).
- **create_group.yaml** — Launch → complete onboarding → create group: name (EUR Group), currency (EUR), participants (Alice, Bob), through Personalize and Review, then assert group created.

These mirror the scenarios in `integration_test/app_test.dart`. Android and iOS can be added later by using `appId` (e.g. `com.shenepoy.hisab`) in the flow config and running Maestro with a device or emulator.

**Seeing what Maestro sees:** To debug selectors or understand why a step fails:

- **Maestro Studio** — Use [Maestro Studio](https://maestro.dev) (desktop app). Connect to **Web** and open your app URL. Use the **Inspect Screen** feature: click an element on the screenshot to see how Maestro identifies it (text, id, etc.) and get suggested commands (`tapOn`, `assertVisible`, …). You can run actions and insert them into a flow.
- **Screenshot flow** — Run the inspect flow to capture what Maestro's browser sees: `maestro test .maestro/inspect.yaml`. A PNG is saved (path shown in the CLI output, often under the current directory or `~/.maestro`). Compare that to what you see in your own browser to spot missing content or wrong page.

**Troubleshooting (web: "Chrome instance exited" / SessionNotCreatedException):** Maestro web uses Selenium and ChromeDriver to drive Chrome. If you see `session not created: Chrome instance exited`:

1. **Chrome vs ChromeDriver version** — The major version of Chrome and the ChromeDriver that Maestro uses must match. Check your Chrome version (e.g. `google-chrome-stable --version` or `chromium --version`). Maestro downloads its own driver; if your Chrome is much newer or older, the session can fail.
2. **Chrome binary path** — If Chrome is not in a standard location, set the executable before running Maestro (Selenium often respects `CHROME_BIN` or `CHROME_EXECUTABLE`), e.g. `export CHROME_BIN=/usr/bin/google-chrome-stable` or `export CHROME_EXECUTABLE=/usr/bin/chromium`.
3. **ChromeDriver verbose log** — The error suggests examining the ChromeDriver verbose log to see why Chrome exited; run with debug/verbose if Maestro or your environment supports it.
4. **Sandbox / headless** — On some Linux setups Chrome needs `--no-sandbox` or `--disable-dev-shm-usage` to start. Maestro may pass some flags already; if you can pass extra Chrome args (e.g. via an env or config), try adding those.

If the problem persists, run the Flutter integration tests on web instead (see "Integration tests" above); they use ChromeDriver directly and you can match Chrome and ChromeDriver versions manually.

## Online integration tests (local Supabase)

Online integration tests run the app against a **local Supabase instance** via Docker. They cover authentication, data sync, and multi-user invite flows — all without touching production.

### Prerequisites

| Requirement | Check |
|---|---|
| Docker | `docker info` (must be running) |
| Supabase CLI | `supabase --version` (install: `npm i -g supabase` or [docs](https://supabase.com/docs/guides/cli/getting-started)) |
| `jq` | `jq --version` (used by the run script to extract credentials) |
| Chrome + ChromeDriver | Same as local integration tests (version-matched) |

### Quick start (one command)

```bash
./scripts/run_online_tests.sh
```

This script:
1. Starts local Supabase containers (`supabase start`)
2. Resets the database — applies all 18 migrations and seeds two test users
3. Extracts `SUPABASE_URL` and `SUPABASE_ANON_KEY` from the running instance
4. Runs `flutter drive` with the online test barrel on web
5. Stops Supabase on exit

Pass `android` to run on a connected device instead:

```bash
./scripts/run_online_tests.sh android
```

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
| `supabase/migrations/20250101000001_*.sql` – `…000018_*.sql` | 18 ordered migrations covering schema, RLS, RPCs, indexes, and features |
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

**Migrations:** The 18 migration files consolidate the complete Supabase schema from `docs/SUPABASE_SETUP.md`:

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
