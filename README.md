# Hisab

Group expense splitting and settle-up app. Built with Flutter, Riverpod, GoRouter, Drift (local), and optional Convex (cloud).

## Features

- **Groups** — Create groups (trips/events) with participants.
- **Expenses** — Log multi-currency expenses with payer and split type (Equal, Uneven, Percentage).
- **Balance** — View who is owed / who owes; settle-up suggests minimal transfers.
- **Settings** — Theme, language, and **Local Only** toggle to use only local storage (no Convex).

## Requirements

- Flutter SDK ^3.10.0
- Dart ^3.10.0

## Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

For web (Chrome): ensure `web/sqlite3.wasm` and `web/drift_worker.dart.js` are present (see [web/README_DRIFT_WEB.md](web/README_DRIFT_WEB.md)).

## Architecture

- **State** — Riverpod 3 (with codegen).
- **Navigation** — GoRouter with ShellRoute and bottom nav.
- **Data** — Repository pattern: `IGroupRepository`, `IParticipantRepository`, `IExpenseRepository` with:
  - **Local** — Drift (SQLite) via `Local*Repository`; IDs as `local_<int>`.
  - **Cloud** — Convex via `Convex*Repository` when Local Only is off.
- **Domain** — `lib/domain/`: Group, Participant, Expense (amounts in cents), SplitType, SettlementTransaction.

## Convex & Auth0 (optional)

For **online sync**, configure both Convex and Auth0. See **[CONFIGURATION.md](CONFIGURATION.md)** for step-by-step setup and troubleshooting.

**First-time:** Copy example files (secrets are gitignored):

```bash
cp lib/core/constants/app_secrets_example.dart lib/core/constants/app_secrets.dart
cp android/secrets.properties.example android/secrets.properties
```

- **Convex** — `npx convex dev` from project root; set `convexDeploymentUrl` in `app_secrets.dart`. Add `AUTH0_DOMAIN` and `AUTH0_CLIENT_ID` in [Convex Dashboard](https://dashboard.convex.dev) → your project → **Dev** deployment → Settings → Environment variables.
- **Auth0** — Native app in Auth0 Dashboard; set `auth0Domain` and `auth0ClientId` in `app_secrets.dart`; set `auth0Domain` and `auth0Scheme` in `android/secrets.properties`. For Android, use a custom scheme (e.g. `com.shenepoy.hisab`) for reliable redirects.

If `convexDeploymentUrl` is empty or Auth0 is not configured, the app runs in **Local Only** mode (Drift only).

### Common issues

| Issue | Quick fix |
|-------|-----------|
| **Auth0 callback mismatch** | Add callback URL to Auth0 Dashboard (see [CONFIGURATION.md](CONFIGURATION.md#5-troubleshooting)) |
| **Auth0 "not found" on Android** | Use custom scheme `auth0Scheme=com.shenepoy.hisab` in secrets |
| **Convex "convex/server" resolve error** | `convex` in dependencies, `npm install`, `CONVEX_TMPDIR=./convex/.tmp` if needed |
| **"Could not find public function"** | Set AUTH0_DOMAIN/AUTH0_CLIENT_ID in Convex Dashboard, run `npx convex dev` |
| **Mutation timeout** | Convex uses Auth0 **ID token** (not access token); sign out and back in if needed |
| **ArgumentValidationError (numbers)** | convex_flutter sends args as strings; Convex validators accept string \| number (already applied) |

Full troubleshooting: [CONFIGURATION.md §5](CONFIGURATION.md#5-troubleshooting).

### Keeping secrets out of git

`app_secrets.dart` and `android/secrets.properties` are gitignored. Never commit them. Use `app_secrets_example.dart` and `secrets.properties.example` as templates.

If secrets were already committed, use [git-filter-repo](https://github.com/newren/git-filter-repo) or [BFG Repo-Cleaner](https://rtyley.github.io/bfg-repo-cleaner/) to rewrite history, then rotate any exposed credentials.

## License

This project is licensed under **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)**.

- You may **share** and **adapt** the material with **attribution**, for **non-commercial** use only, and you must **share adaptations** under the same license.
- Full legal text: [LICENSE](LICENSE) in this repo, or [legalcode](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode) on the CC site.
- Human-readable summary: [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).

