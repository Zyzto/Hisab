# Documentation

Guides for running, shipping, and extending **Hisab**. Start with the root [README](../README.md) for product overview and a short develop path; use this index when you need depth.

---

## Start here

| Doc | Use when you need to… |
|-----|------------------------|
| [CONFIGURATION.md](CONFIGURATION.md) | Pass `--dart-define` / define files; online vs local-only |
| [LOCAL_TEST_ENV.md](LOCAL_TEST_ENV.md) | Run Supabase + Edge Functions on LAN (Podman) for device tests |
| [SUPABASE_SETUP.md](SUPABASE_SETUP.md) | Create a hosted project, migrations, Auth, Edge deploy |
| [CODEBASE.md](CODEBASE.md) | Map features (incl. Profile), sync, shell nav, notifications, and where code lives |
| [../SECURITY.md](../SECURITY.md) | Know what never lands in a public commit |

---

## Setup and release

| Doc | Topic |
|-----|--------|
| [RELEASE_SETUP.md](RELEASE_SETUP.md) | Keystore, Play, Firebase Hosting, one-time release checklist |
| [GITHUB_ACTIONS_SECRETS.md](GITHUB_ACTIONS_SECRETS.md) | CI secret names and where each value comes from |
| [SUPABASE_BACKUP.md](SUPABASE_BACKUP.md) | Database backup and restore |

---

## Backend

| Doc | Topic |
|-----|--------|
| [EDGE_FUNCTIONS.md](EDGE_FUNCTIONS.md) | Functions list, local smoke, deploy commands |

---

## Product

| Doc | Topic |
|-----|--------|
| [PERSONAL_FEATURE.md](PERSONAL_FEATURE.md) | Personal (solo) lists — data model and flows |
| [TRANSACTION_SCANNER.md](TRANSACTION_SCANNER.md) | Android notification → draft → personal expense |
| [I18N.md](I18N.md) | `en` / `ar` keys, conventions, scanner strings |
| [DELETE_ACCOUNT.md](DELETE_ACCOUNT.md) | Delete local/cloud data; account deletion request |
| [PLAY_CONSOLE_DECLARATIONS.md](PLAY_CONSOLE_DECLARATIONS.md) | Play Console privacy, ads, content ratings |

---

## Web and UI

| Doc | Topic |
|-----|--------|
| [WEB_DEBUGGING.md](WEB_DEBUGGING.md) | Meaningful Chrome console / DevTools for Flutter web |
| [WEB_IOS_SAFARI_PERFORMANCE.md](WEB_IOS_SAFARI_PERFORMANCE.md) | Per-platform web/native UI perf (`UiPerf`), iOS Safari checklist |
| [ADAPTIVE_RESPONSIVE_PLAN.md](ADAPTIVE_RESPONSIVE_PLAN.md) | Breakpoints, SafeArea, large-screen direction |
| [MODAL_CENTERING_AND_RESPONSIVE_SHEET.md](MODAL_CENTERING_AND_RESPONSIVE_SHEET.md) | Modal centering, dismiss-outside, sheet behavior |

---

## Tests

| Doc | Topic |
|-----|--------|
| [../test/README.md](../test/README.md) | Unit, widget, integration, online, and Edge smoke |

---

## Suggested reading order

1. **Contributor, no cloud** — [CONFIGURATION.md](CONFIGURATION.md) (local-only), then [CODEBASE.md](CODEBASE.md).
2. **Device + local backend** — [LOCAL_TEST_ENV.md](LOCAL_TEST_ENV.md), then [EDGE_FUNCTIONS.md](EDGE_FUNCTIONS.md).
3. **Hosted online** — [SUPABASE_SETUP.md](SUPABASE_SETUP.md), then [CONFIGURATION.md](CONFIGURATION.md) for defines.
4. **Ship a release** — [RELEASE_SETUP.md](RELEASE_SETUP.md) + [GITHUB_ACTIONS_SECRETS.md](GITHUB_ACTIONS_SECRETS.md); keep [SECURITY.md](../SECURITY.md) open while adding secrets.
