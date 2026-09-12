# Hisab

Hisab is a local-first expense splitter for trips, households, and personal
budgets. It is a FOSS Flutter app for Android, iOS, and web.

The public build is intentionally self-contained:

- no account, server, subscription, ads, or app-initiated network requests;
- unlimited local groups, participants, expenses, balances, and settlements;
- local receipt OCR on supported mobile devices;
- local Android transaction scanning with drafts and history;
- JSON/CSV/ZIP backup export and import.

All records are stored in the device's local SQLite database. Use Settings →
Data & Backup to move records between devices. Existing local records and
legacy database tables are preserved during upgrades.

## Quick start

```bash
flutter pub get
flutter run -d chrome
flutter run --flavor foss
```

Web builds need the checked-in PowerSync worker and SQLite WASM assets. If a
fresh checkout does not contain them, run:

```bash
flutter pub run powersync:setup_web
```

No keys, environment variables, or build-time defines are required.

## Build and checks

```bash
bash scripts/ci/build_android.sh debug
bash scripts/ci/build_web.sh
bash scripts/ci/assert_offline_only.sh
bash scripts/verify_infra.sh
flutter analyze
flutter test
```

Android has one public product flavor: `foss`. The iOS and web targets use the
same local-only application sources.

## Project layout

- `lib/domain/` — local expense, participant, balance, and settlement models.
- `lib/core/database/` — PowerSync SQLite schema and startup.
- `lib/core/repository/` — local repository interfaces and implementations.
- `lib/features/` — groups, expenses, backups, scanner, and settings.
- `assets/tessdata/` — bundled OCR models.
- `web/` — Flutter web shell and local database assets.

Feature modules depend on repository interfaces. Local mutations are written
to SQLite immediately; no remote queue or transport is required.

The release checks verify that the application remains self-contained. Keep
generated build output outside the source tree when preparing a release.

## Privacy and data deletion

See the [Privacy Policy](https://hisab.shenepoy.com/privacy/) and [local data
deletion instructions](https://hisab.shenepoy.com/delete-account/). The app
does not create an account or store records on a Hisab server.

## License and contribution

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and
[LICENSE](LICENSE).
