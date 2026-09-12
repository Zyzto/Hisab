# Codebase overview

Hisab is an offline-first Flutter application. SQLite/PowerSync is the UI
source of truth and every local mutation is written immediately.

## Main layers

- lib/domain/ — groups, participants, expenses, tags, balances, and
  settlements.
- lib/core/database/ — local database startup and schema.
- lib/core/repository/ — repository interfaces and local implementations.
- lib/features/groups/ — group creation, people, categories, analytics, and
  settings.
- lib/features/expenses/ — expense forms, splits, receipts, and galleries.
- lib/features/settings/ — local settings and backup import/export.
- lib/features/transaction_scanner/ — optional local Android notification
  scanner.
- lib/core/debug/ — local diagnostics and the draggable debug menu.

Feature code depends on repository interfaces rather than database details.
The startup path in lib/main.dart initializes settings and a local database,
then mounts the application with a local database provider override.

## Local database

The schema in lib/core/database/powersync_schema.dart contains current tables
and legacy tables needed to open older installations. Upgrades must not delete
old tables automatically. Backup import/export is the supported way to move
records between devices.

The web build uses web/sqlite3.wasm and web/powersync_db.worker.js. The worker
is a local database asset; the app does not connect it to a remote endpoint.

## Navigation and UI

GoRouter owns the local routes for home, groups, expenses, settings,
onboarding, backups, scanner, and diagnostics. The group detail screen keeps
expense, balance, and people tabs alive so local lists retain their scroll
state.

Dialogs and responsive sheets use the helpers in
lib/core/layout/responsive_sheet.dart. List tiles with a colored surface are
wrapped in their own Material so ink effects remain visible.

## Receipt and scanner behavior

Receipt images are stored as local files. Mobile OCR uses platform/native OCR
bridges and bundled extraction heuristics. The Android transaction scanner
stores captured text, drafts, and history locally and never uploads them.

## Settings and localization

Settings are registered in lib/core/settings/settings_definitions.dart.
English and Arabic JSON files must keep identical keys and placeholders.
test/translations_test.dart checks parity and referenced keys.

## Code generation

After changing Riverpod providers, run:

    dart run build_runner build

Generated files are checked in so a clean checkout can analyze and build.

## Verification

    bash scripts/ci/assert_offline_only.sh
    bash scripts/verify_security.sh
    bash scripts/verify_infra.sh
    flutter analyze
    flutter test
