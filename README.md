# Hisab

Group expense splitting and settle-up app (Tricount-style). Built with Flutter, Riverpod, GoRouter, Drift (local), and optional Convex (cloud).

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

## Convex (optional)

1. Install [Convex CLI](https://docs.convex.dev) and create a project.
2. From project root: `npx convex dev` to push schema and functions from `convex/`.
3. Set your deployment URL in `lib/core/constants/convex_config.dart` (`convexDeploymentUrl`).
4. Turn off **Local Only** in Settings to use Convex.

If `convexDeploymentUrl` is empty, Convex is not initialized and the app runs in Local Only mode only.

## License

This project is licensed under **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)**.

- You may **share** and **adapt** the material with **attribution**, for **non-commercial** use only, and you must **share adaptations** under the same license.
- Full legal text: [LICENSE](LICENSE) in this repo, or [legalcode](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode) on the CC site.
- Human-readable summary: [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).

## Credits

Architecture and UI patterns follow the [mizaniyah](https://github.com/your-repo/mizaniyah) reference app.
