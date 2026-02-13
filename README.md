# Hisab

Group expense splitting and settle-up app. Built with Flutter, Riverpod, GoRouter, and Supabase.

## Features

- **Groups** — Create groups (trips/events) with participants.
- **Expenses** — Log multi-currency expenses with payer and split type (Equal, Parts, Amounts).
- **Balance** — View who is owed / who owes; settle-up suggests minimal transfers.
- **Record Settlement** — Tap a settlement suggestion to record the payment and zero out the debt.
- **Settings** — Theme, language, and **Local Only** toggle.
- **Offline-first** — Works entirely offline via local SQLite. Syncs directly with Supabase when online.

## Two Modes

| Mode | What works | Data location |
|------|-----------|---------------|
| **Local-Only** (default) | **Everything** — full CRUD, settlement, no restrictions | Local SQLite only |
| **Online** (with Supabase) | **Everything** + invites, members, cross-device sync | Supabase + local SQLite cache |

When in Online mode and temporarily offline, you can still add expenses (queued for later sync). Other features like invites and member management require connectivity.

## Requirements

- Flutter SDK ^3.10.0
- Dart ^3.10.0

## Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Without `--dart-define` parameters the app runs in **local-only mode** (no sign-in, no sync).

### Online mode

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
```

For web: ensure `web/sqlite3.wasm` is present. Generate it with:

```bash
dart run powersync:setup_web
```

## Architecture

- **State** — Riverpod 3 with `riverpod_annotation` codegen.
- **Navigation** — GoRouter with ShellRoute and bottom nav.
- **Data** — Repository pattern: `IGroupRepository`, `IParticipantRepository`, `IExpenseRepository`.
  - Local SQLite (via PowerSync package) is the single local database engine.
  - When online, writes go to Supabase first, then update local cache.
  - Reads always come from local SQLite for speed and reactivity.
  - Complex operations (invite accept, ownership transfer, etc.) use Supabase RPC functions.
- **Sync** — `DataSyncService` handles: full fetch from Supabase, push pending offline writes, periodic refresh.
- **Auth** — Supabase Auth (email/password, magic link, Google OAuth, GitHub OAuth).
- **Domain** — `lib/domain/`: Group, Participant, Expense (amounts in cents), SplitType, SettlementTransaction.

## Supabase (optional)

For **online mode**, set up Supabase. See **[SUPABASE_SETUP.md](SUPABASE_SETUP.md)** for the full step-by-step guide covering:

- Creating the Supabase project and applying database migrations
- Configuring authentication providers (email, Google, GitHub)
- Deploying Edge Functions (invite-redirect, telemetry)
- Configuring `--dart-define` parameters

If no `--dart-define` values are provided, the app runs in **local-only mode** — all features work except sign-in and cross-device sync.

### Common issues

| Issue | Quick fix |
|-------|-----------|
| **App shows local-only mode** | Ensure both `--dart-define` params are set |
| **SQLite web crash** | Run `dart run powersync:setup_web` to download WASM |
| **OAuth redirect fails** | Check Supabase Auth redirect URLs match your app |
| **Migration fails** | Ensure stable internet; migration is idempotent |

Full configuration reference: [CONFIGURATION.md](CONFIGURATION.md).

### Keeping secrets out of git

All secrets are provided at build time via `--dart-define` — nothing is committed to the repository. The only gitignored secrets file is `lib/core/constants/app_secrets.dart` which contains fallback placeholders.

## License

This project is licensed under **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)**.

- You may **share** and **adapt** the material with **attribution**, for **non-commercial** use only, and you must **share adaptations** under the same license.
- Full legal text: [LICENSE](LICENSE) in this repo, or [legalcode](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode) on the CC site.
- Human-readable summary: [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
