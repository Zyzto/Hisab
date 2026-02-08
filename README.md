# Hisab

Group expense splitting and settle-up app (Tricount-style). Built with Flutter, Riverpod, GoRouter, Drift (local), and optional Convex (cloud).

## Features

- **Groups**: Create groups (trips/events) with participants.
- **Expenses**: Log multi-currency expenses with payer and split type (Equal, Uneven, Percentage).
- **Balance**: View who is owed / who owes; settle-up suggests minimal transfers.
- **Settings**: Theme, language, and **Local Only** toggle to use only local storage (no Convex).

## Architecture

- **State**: Riverpod 3 (with codegen).
- **Navigation**: GoRouter with ShellRoute and bottom nav.
- **Data**: Repository pattern — `IGroupRepository`, `IParticipantRepository`, `IExpenseRepository` with:
  - **Local**: Drift (SQLite) via `Local*Repository`; IDs as `local_<int>`.
  - **Cloud**: Convex via `Convex*Repository` when Local Only is off.
- **Domain**: `lib/domain/` — Group, Participant, Expense (amounts in cents), SplitType, SettlementTransaction.

## Convex (optional)

1. Install Convex CLI and create a project: [Convex docs](https://docs.convex.dev).
2. From project root: `npx convex dev` to push schema and functions from `convex/`.
3. Set your deployment URL in `lib/core/constants/convex_config.dart` (`convexDeploymentUrl`).
4. Turn off **Local Only** in Settings to use Convex.

If `convexDeploymentUrl` is empty, Convex is not initialized; the app works in Local Only mode only.

## Run

- `flutter pub get`
- `dart run build_runner build --delete-conflicting-outputs`
- `flutter run`

## Credits

Architecture and UI patterns follow the [mizaniyah](https://github.com/your-repo/mizaniyah) reference app.
