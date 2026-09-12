# Configuration

The public Hisab build has no service configuration. It does not require
accounts, keys, secrets, runtime endpoints, or `dart-define` values.

That is a product boundary, not an omitted setup step: the app must not make
app-initiated network requests.

## Development

`flutter pub get`
`flutter run -d chrome`
`flutter run --flavor foss`

PowerSync web assets are checked in. To recreate them after a dependency
upgrade:

`flutter pub run powersync:setup_web`

## Release checks

`bash scripts/ci/assert_offline_only.sh`
`bash scripts/verify_security.sh`
`bash scripts/verify_infra.sh`
`flutter analyze`
`flutter test`

Build artifacts:

`bash scripts/ci/build_android.sh release`
`bash scripts/ci/build_web.sh`

Android uses only the `foss` flavor. Signing is supplied by the release
environment; development builds use the documented local fallback.

## Local data

PowerSync/SQLite is initialized during startup and is the UI source of truth.
Repositories write local mutations immediately. Backups are created and
restored locally through Settings → Data & Backup.

Schema upgrades must preserve old tables and columns unless a future migration
explicitly provides an export-and-restore path. In particular, legacy queue
and membership tables are retained so an upgrade never destroys user data.

## Fonts and assets

The app uses bundled Flutter/system fonts and checked-in image/OCR assets. No
runtime font or asset download is performed.
