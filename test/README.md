# Tests

The suite runs without service credentials or a running server. Tests use the
same local data model and startup path as the application.

`flutter analyze`
`flutter test`

The tests cover:

- local SQLite/PowerSync repository behavior;
- backup parsing and restore-safe data handling;
- receipt OCR and local extraction fixtures;
- transaction scanner parsing and duplicate detection;
- group, expense, balance, settlement, settings, and navigation widgets;
- English/Arabic translation parity;
- web PWA and local database bootstrap behavior.

Some repository tests skip when the native PowerSync library is unavailable.
Install the platform prerequisites or use the repository's Nix environment
when running those tests locally.

## Integration tests

Integration tests use a temporary local database and the same local startup
path as the application:

`flutter test integration_test`

Web database assets are supplied by `web/sqlite3.wasm` and
`web/powersync_db.worker.js`.

The suite tests immediate SQLite writes, backups, local receipts, scanner
drafts, and legacy schema preservation.
