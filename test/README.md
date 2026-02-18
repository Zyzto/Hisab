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

## PowerSync

Tests in `local_database_test.dart`, `sync_test.dart`, and `supabase_repository_test.dart` depend on the PowerSync native binary. On first run they probe for availability (e.g. by initializing a temporary database). If the binary cannot be loaded (e.g. in some CI environments or when the platform is unsupported), those tests are skipped; the rest of the suite still runs.

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
