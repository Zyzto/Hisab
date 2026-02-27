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

**App targets:** Web (desktop/tablet/mobile), Android, iOS. Integration tests run on a device or desktop that Flutter supports for `integration_test` (not web — Flutter does not support web for integration tests yet).

Run on Linux desktop (e.g. CI or local):

```bash
flutter test integration_test/ -d linux
```

Run on Android or iOS when an emulator/device is available:

```bash
flutter test integration_test/ -d <device_id>
```

- **Bootstrap:** `integration_test/integration_test_bootstrap.dart` initializes EasyLocalization, a temp DB, and settings (onboarding completed, local-only), then calls `runApp(...)` with the same overrides as production. No Supabase/Firebase or LoggingService.
- **Tests:** `integration_test/app_test.dart` contains a smoke test (app opens to home) and a create-group flow (FAB → Create Group → name → Next → Skip → Next → Create Group).
- **Requirements:** PowerSync native binary (same as `local_database_test.dart`). If the binary is unavailable, the bootstrap returns `false` and tests fail with a clear message.
- **CI:** Uses Linux desktop (`flutter test integration_test/ -d linux` with xvfb). For Android/iOS, use an emulator or Firebase Test Lab.

## Supabase

There are no live Supabase calls in CI. Online-mode repository behaviour is tested with a fake or mock client. For optional manual integration tests against a real Supabase project, run with:

```bash
flutter test --dart-define=SUPABASE_URL=https://xxxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=...
```

(No script or workflow change is required; document and run manually if needed.)

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
