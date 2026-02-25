# Hisab Development Guide

See `README.md` for project overview, run instructions, and architecture.
See `docs/CODEBASE.md` for detailed codebase structure and conventions.
See `docs/CONFIGURATION.md` for build-time configuration reference.
See `test/README.md` for test conventions and helpers.

## Cursor Cloud specific instructions

### Environment

- **Flutter SDK 3.38.2** is installed at `/opt/flutter`. The PATH is configured in `~/.bashrc`.
- **Node.js 22** is available (functions/ specifies Node 20 engine but works fine with 22).
- **Chrome** is pre-installed for `flutter run -d chrome` and web testing.

### Key commands

| Task | Command |
|------|---------|
| Install Dart deps | `flutter pub get` |
| Code generation | `dart run build_runner build --delete-conflicting-outputs` |
| Web SQLite setup | `dart run powersync:setup_web` |
| Functions deps | `cd functions && npm install` |
| Lint | `flutter analyze` |
| Tests | `flutter test` |
| Run web (local-only) | `flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0` |
| Run web (Chrome) | `flutter run -d chrome` |

### Gotchas

- **Code generation is required** after changing Riverpod providers or annotated code. Always run `dart run build_runner build --delete-conflicting-outputs` before analyzing or testing.
- **PowerSync web assets** (`web/sqlite3.wasm`, worker JS files) must be present for the web target. Run `dart run powersync:setup_web` if they are missing.
- **Local-only mode** (default, no `--dart-define` params) works for groups, participants, and navigation. The expense form currently crashes in local-only mode with a Supabase initialization assertion error — this is a known app-level bug, not an environment issue.
- **Test failures**: 12 of 133 tests fail on this branch (`group_card_widget_test.dart` x10, `floating_nav_bar_widget_test.dart` x2) due to `material_symbols_icons` icon codepoint lookups in widget tests. These are pre-existing test issues, not environment problems. The remaining 121 tests pass.
- **Flutter web server** takes ~60 seconds for the initial compilation. Subsequent hot reloads are fast.
- The app uses a **canvas-based renderer** on web, so browser DevTools element inspection does not work on Flutter widgets.
