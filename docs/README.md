# Documentation

Guides for running, shipping, and extending **Hisab**. Start with the root [README](../README.md) for product overview and a short develop path; use this index when you need depth.

---

## Start here

| Doc | Use when you need to… |
|-----|------------------------|
| [CONFIGURATION.md](CONFIGURATION.md) | Build-time flags; online vs local-only |
| [CODEBASE.md](CODEBASE.md) | Map features (incl. Profile), sync, shell nav, notifications, and where code lives |
| [SELF_HOSTING.md](SELF_HOSTING.md) | Attach your own backend to this client |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | Workflow, checks, and the CLA |
| [../SECURITY.md](../SECURITY.md) | Know what never lands in a public commit |

---

## Setup and release

| Doc | Topic |
|-----|--------|
| [RELEASE_SETUP.md](RELEASE_SETUP.md) | Keystore, Play, Firebase Hosting, one-time release checklist |
| [../.cursor/skills/hisab-release-checks/SKILL.md](../.cursor/skills/hisab-release-checks/SKILL.md) | Agent skill: security + infra checks, release gate |

---

## Backend

This repository ships **no backend**. It ships the contract one must satisfy.

| Doc | Topic |
|-----|--------|
| [SELF_HOSTING.md](SELF_HOSTING.md) | Implement `CloudBackend` against your own server, step by step |
| [BACKEND_BEHAVIOUR.md](BACKEND_BEHAVIOUR.md) | Server-side rules the client assumes (invites, membership, deletion) |
| [../packages/hisab_backend/README.md](../packages/hisab_backend/README.md) | Facet-by-facet API reference |

The hosted Hisab backend is a separate proprietary project and is not part of
this repository.

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
| [../test/README.md](../test/README.md) | Unit, widget, and integration tests |

---

## Suggested reading order

1. **Contributor, no cloud** — [CONFIGURATION.md](CONFIGURATION.md) (local-only), then [CODEBASE.md](CODEBASE.md), then [../CONTRIBUTING.md](../CONTRIBUTING.md).
2. **Running your own backend** — [SELF_HOSTING.md](SELF_HOSTING.md), then [BACKEND_BEHAVIOUR.md](BACKEND_BEHAVIOUR.md), then [../packages/hisab_backend/README.md](../packages/hisab_backend/README.md) as reference.
3. **Ship a FOSS release** — [RELEASE_SETUP.md](RELEASE_SETUP.md); keep [SECURITY.md](../SECURITY.md) open while adding secrets.
