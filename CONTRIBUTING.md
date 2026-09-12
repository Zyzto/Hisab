# Contributing to Hisab

Thanks for wanting to help. The project is a Flutter application with a local
SQLite/PowerSync data model and platform-specific local integrations.

## What lives here

The repository builds a fully functional local app on its own. Adaptive chrome
lives in the separate [Safaeh](https://github.com/Zyzto/Safaeh) package
(MPL-2.0), and CI verifies the local build on every push.

## Contributor Licence Agreement

**Every contribution requires a CLA.** This is not paperwork; it is what keeps
the project's structure legal.

Hisab is AGPL-3.0. A single party holds the copyright to the AGPL source and
can therefore also license it under compatible terms for official releases.

The first contribution merged without a CLA ends that, permanently, for
everyone.

By opening a pull request you agree that:

1. You are the sole author of the contribution, or you have the right to submit
   it under these terms.
2. You grant Zyzto a perpetual, worldwide, irrevocable, royalty-free licence to
   use, reproduce, modify, sublicense and distribute your contribution,
   including under licences other than the AGPL, and including as part of a
   combined work with proprietary components.
3. Your contribution stays available under the AGPL to everyone else. This
   grant is *additional* to that licence, not a replacement — you keep your
   copyright. Changes to Safaeh belong in
   [Zyzto/Safaeh](https://github.com/Zyzto/Safaeh) under MPL-2.0.
4. You provide it without warranty of any kind.

Say so explicitly in your first pull request:

> I have read CONTRIBUTING.md and I agree to the CLA.

If you cannot agree to this, please open an issue describing the change rather
than a pull request. A good bug report is worth more than a patch that cannot
be merged.

## Before you open a pull request

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format lib test packages
flutter analyze
flutter test
bash scripts/run_release_checks.sh
```

CI runs all of these plus a self-contained build guard. Changes should keep
the application usable without any external service.

## Secrets

This repository is public and has no production credentials in it. Never commit
API keys, service-account JSON or filled define files — `scripts/verify_security.sh`
runs on every push and in a pre-push hook, but it is a backstop, not a
permission slip. See [SECURITY.md](SECURITY.md).

Install the hooks once:

```bash
bash scripts/install_git_hooks.sh
```

## Style

Match the surrounding code. Comments explain constraints and trade-offs, not
what the next line does. New user-facing strings go through the localization
files in `assets/translations/` — both English and Arabic, since the app ships
RTL.
