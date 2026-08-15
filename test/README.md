# Tests

<!-- markdownlint-disable MD031 MD032 MD036 MD040 MD060 -->

How to run unit, widget and integration tests for Hisab. Product overview:
[../README.md](../README.md). Doc index: [../docs/README.md](../docs/README.md).

Every test here runs **with no backend and no network**. That is deliberate:
this repository builds an offline app, so its suite must pass on a machine with
nothing installed but Flutter. Tests that need a live server belong with that
server, not here — see [../docs/SELF_HOSTING.md](../docs/SELF_HOSTING.md).

Cloud-facing code is covered through fakes. `test/support/fake_cloud.dart`
implements every `CloudBackend` facet in memory, so repository and provider
tests exercise the online paths without a service.

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

A cross-platform Dart runner runs unit/widget tests, then sequentially: Android integration (with optional AVD launch) and web integration (ChromeDriver + `flutter drive`), and prints a summary with log paths.

**From repo root (all platforms):**

```bash
dart run tool/run_all_tests.dart
```

Optional wrappers: `./scripts/run_all_tests.sh` (Linux/macOS) or `scripts\run_all_tests.bat` (Windows).

**Options:** `--skip-unit` (skip unit & widget tests), `--skip-android`, `--skip-web`, `--no-avd` (do not launch an emulator; fail if no Android device is present).

**Logs:** Written to `logs/test_run_<timestamp>/` (e.g. `unit_widget.log`, `integration_android.log`, `integration_web.log`). The summary table and any error log paths are printed at the end.

**Prerequisites:** Flutter SDK, Dart SDK. For Android: a device or AVD (runner can launch the first available emulator). For web: Chrome and ChromeDriver on PATH (version-matched); set `CHROME_EXECUTABLE` if Chrome is not in the default location.

## Widget tests

- **Layout:** Test directories mirror `lib/`: `test/core/`, `test/groups/`, `test/expenses/`, `test/settings/`, `test/pages/`, `test/onboarding/`, plus `test/balance/`, `test/` (app, error content, etc.). Onboarding widget tests use **bounded pumps** (not `pumpAndSettle`) because language/theme demo timers and welcome stagger animations never idle.
- **Helper:** `test/widget_test_helpers.dart` provides:
  - `pumpApp(tester, child: widget, locale: Locale('en')|Locale('ar'), pumpAndSettle: true)` — wraps the widget in EasyLocalization + MaterialApp + Scaffold, then pumps. Use for presentational widgets that do not need Riverpod.
  - `testSupportedLocales` — `[Locale('en'), Locale('ar')]` for use when building EasyLocalization manually (e.g. with ProviderScope overrides).
- **Conventions:** Use `setUpAll` to disable Easy Localization build logging (`EasyLocalization.logger.enableBuildModes = []`). For widgets that depend on providers, wrap in `ProviderScope(overrides: [...])` then EasyLocalization then MaterialApp (see e.g. `test/balance/balance_list_widget_test.dart`, `test/core/sync_status_chip_widget_test.dart`). The balance list test overrides `myMemberInGroupProvider` and `myRoleInGroupProvider` to assert both owner (record enabled) and member-not-debtor (record disabled) behaviour.
- **Locale:** Key widgets have at least one test with `locale: Locale('ar')` (via `pumpApp` or manual `startLocale: Locale('ar')`) to ensure RTL/translations work.
- **Edge cases:** Tests cover empty/zero/long content and optional parameters where relevant (e.g. GroupCard empty name, personal group, pin; ExpenseListTile zero amount, long title, income type; ExpandableSection empty `trailingSummary`).

## Receipt OCR fixtures

| Path | Role |
|------|------|
| `test/fixtures/receipts/*.txt` | Clean / curated receipt text for CI (`receipt_real_fixtures_test.dart`) |
| `test/fixtures/receipts/ocr_raw/*.txt` | Noisy Tesseract OCR dumps for extractor regression (`receipt_raw_ocr_score_test.dart`) |
| `test/support/receipt_ocr_expectations.dart` | Shared 8-sample store/total/VAT expects + `scoreOcrDir` |

Naming: clean fixtures use short names (`texas.txt`); raw OCR keeps sample ids (`texas_simple.txt`). Local scratch photos/OCR outputs live under gitignored `tmp/receipts/` (never commit). Score arbitrary OCR folders:

```bash
dart run tool/score_ocr_dirs.dart ocr2=tmp/receipts/ocr2
dart run tool/score_ocr_dirs.dart fixtures=test/fixtures/receipts/ocr_raw
```

## Schema alignment

`test/schema_alignment_test.dart` asserts that synced table columns match between `lib/core/database/powersync_schema.dart` and the INSERT column lists in `lib/core/database/sync_engine.dart`. It runs with `flutter test` and fails the build on mismatch. See `docs/CODEBASE.md` "Schema alignment".

## PowerSync

Tests in `local_database_test.dart`, `sync_test.dart`, and `cloud_repository_test.dart` depend on the PowerSync native binary. On first run they probe for availability (e.g. by initializing a temporary database). If the binary cannot be loaded (e.g. in some CI environments or when the platform is unsupported), those tests are skipped; the rest of the suite still runs.

## Integration tests

Full-app integration tests live in `integration_test/`. They run the real UI (App + GoRouter + providers) with a temp PowerSync DB and no backend or Firebase.

**Platforms:** Integration tests target the **web app** (Chrome). CI runs them with `flutter drive` and `-d chrome`. You can also run on Android or iOS when a device/emulator is available.

**Dart Debug Chrome extension:** For interactive web debugging (e.g. `flutter run -d web-server` or `flutter run -d chrome`), install the [Dart Debug Extension](https://chromewebstore.google.com/detail/dart-debug-extension/eljbmlghnomdjgdjmbdekegdkbabckhm) in Chrome to get meaningful console messages, Dart stack traces, and DevTools. See [docs/WEB_DEBUGGING.md](../docs/WEB_DEBUGGING.md). Integration test runs (`flutter drive --release`) do not use the extension.

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

**One-command local run (Chrome, no global ChromeDriver):** From repo root, `./scripts/run_web_integration_tests.sh` installs ChromeDriver via npm (`package.json`) and runs the web integration tests. **GitHub Actions do not use this script:** the release workflow uses `nanasess/setup-chromedriver@v2` and does not run `npm install`, so CI is unchanged.

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
    test_helpers.dart            -- reusable finders, tap helpers, wait helpers
    fake_image_picker.dart       -- mock ImagePickerPlatform for photo tests
    test_db_path.dart            -- platform-conditional DB path (io/stub)
  smoke_test.dart                -- app opens, home visible, nav works
  onboarding_test.dart           -- full 4-page onboarding flow (Welcome → Preferences → Permissions → Connect)
  group_flows_test.dart          -- create group, detail tabs, settings, archive
  personal_test.dart             -- create personal budget, simplified UI, add expense
  expense_flows_test.dart        -- add/edit/view expenses, all split types, income/transfer
  expense_photos_test.dart       -- gallery photo attach (mobile only; not in app_test web suite)
  balance_test.dart              -- verify balances, record settlement
  settings_test.dart             -- theme, language, font size, telemetry toggle
  app_test.dart                  -- barrel that imports all local-only web-safe test files
test_driver/
  integration_test.dart          -- web driver entry point (custom diagnostics)
tool/
  run_all_tests.dart            -- cross-platform runner: unit/widget, then Android + web integration, summary
  score_ocr_dirs.dart           -- score OCR text dirs against shared receipt expects
scripts/
  run_all_tests.sh, run_all_tests.bat  -- wrappers for dart run tool/run_all_tests.dart
```

- **Bootstrap:** `integration_test/helpers/test_bootstrap.dart` initializes EasyLocalization, a temp PowerSync DB, and settings (onboarding completed, local-only), then calls `runApp(...)` with the same overrides as production. No backend, Firebase or LoggingService. Set `skipOnboarding: false` to exercise the onboarding flow.
- **Helpers:** `integration_test/helpers/test_helpers.dart` provides `pumpAndSettleWithTimeout`, `tapAndSettle`, `enterTextAndPump` (with web fallback), `waitForWidget`, `scrollUntilVisible`, `tapSubmitExpenseButton`, `ensureFormClosed`, `stage` (stage-based progress recording), and `ensureBootstrapReady`.
- **Test flows** (`app_test.dart`):
  - **Smoke:** App opens to home (Groups/Personal/FAB visible); navigate to Settings and back.
  - **Onboarding:** Complete all 4 pages (Welcome → Preferences → Permissions → Connect) and land on home.
  - **Group flows:** Create group with participants (Alice, Bob) → verify detail tabs (Expenses/Balance/People) → open group settings → change icon/color/currency/settlement → archive group.
  - **Personal:** Create personal budget → verify simplified UI (no Balance/People tabs) → add expense.
  - **Expense flows:** Create group with 2 participants → add expenses with tags, description, bill breakdown, long titles, currency change, exchange rates → all split types → view detail → edit expense → add Income and Transfer. Photo attach is `expense_photos_test.dart` (mobile only; `MockPlatformInterfaceMixin` must not ship in the web `--release` suite).
  - **Balance:** Create group, add expense → switch to Balance tab → verify balances and settlement suggestions → record and freeze settlements. The test user is the group owner, so they can record any settlement (by default only the owner or the debtor can record; see group setting "Members can record settlements for others").
  - **Settings:** Change theme, language (Arabic and back), font size, toggle telemetry; verify settings persist across navigation.
- **Requirements:** For web, Chrome/Chromium must be installed (set `CHROME_EXECUTABLE` if needed). PowerSync is used; on web it uses the web-backed storage. If the bootstrap fails (e.g. PowerSync unavailable), tests fail with a clear message.
- **CI:** Runs the integration tests on **web** (`flutter drive` with `-d chrome`). For Android/iOS, use an emulator or Firebase Test Lab.

## Testing against a real backend

End-to-end auth, sync and invite tests need a live server, so they live with
whatever backend you run rather than in this repository. If you implement the
`CloudBackend` contract yourself, the shape that works is: bring up your stack,
compose your package over this checkout with a `pubspec_overrides.yaml`, and
point `flutter drive` at a barrel of online tests with your defines passed
through. [../docs/SELF_HOSTING.md](../docs/SELF_HOSTING.md) covers the
composition step.

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
