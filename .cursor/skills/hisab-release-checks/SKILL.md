---
name: hisab-release-checks
description: >-
  Run Hisab pre-release checks for the public client (static scripts, offline
  build guard, security-review subagent, tests, tag/CI watch). Use when the user
  asks for a security check, infra check, release gate, release double-check,
  bump release, push tag, or to verify CI before/after shipping.
---

# Hisab release checks

Pre-release gate for the **public Hisab client**. This repository has no
backend: it builds the FOSS, offline-only app. Backend and cloud-build checks
live in the private repo's own runbook, so do not look for migrations, Edge
Functions or production secrets here.

**Do not start the app** (`never run project` user rule). Prefer scripts + CI.

## When to run

- User asks for **security check**, **infra check**, **release checks**, or **double-check** before ship
- User asks to **bump release**, **push tag**, or **make sure CI succeeds**
- After changes to build config, workflows, signing, or anything touching the backend contract

## Fixed project facts

| Item | Value |
|------|--------|
| Release workflow | `.github/workflows/release.yml` (tags `v*`, FOSS APKs, draft release) |
| CI workflow | `.github/workflows/ci.yml` (checks, tests, offline build guard) |
| Version | `pubspec.yaml` → `MARKETING+BUILD` (e.g. `0.6.16+65`) |
| Tag style | `v0.6.16` annotated; commit `chore(release): v0.6.16` |
| Flutter version | `.flutter-version` — single source of truth for every workflow |

## Checklist (copy and track)

```
Release checks:
- [ ] 1. Static security (`verify_security.sh`)
- [ ] 2. Static infra (`verify_infra.sh`)
- [ ] 3. Offline guard (`assert_offline_only.sh`)
- [ ] 4. Security review subagent (diff)
- [ ] 5. flutter test
- [ ] 6. Contract/docs touch-up if behavior changed
- [ ] 7. Version bump + commit (only if user asked to release)
- [ ] 8. Push + tag + watch CI (only if user asked)
- [ ] 9. Private cloud release, then publish the draft (only if user asked)
```

## 1–3. Static gates (always)

```bash
bash ./scripts/run_release_checks.sh
bash ./scripts/ci/assert_offline_only.sh
```

The offline guard is the one that matters most for this repo: it fails if a
backend dependency or a tracked credential entered the tree, which is exactly
the mistake that would quietly break the FOSS build.

**Before any `git push`:** ensure hooks are installed
(`bash ./scripts/install_git_hooks.sh`). `.githooks/pre-push` and
`.cursor/hooks/block-push-if-secrets.sh` both run `verify_security.sh` against
the commit tree. Do not use `--no-verify` unless the user explicitly asks.

## 4. Security review subagent

Launch exactly one `security-review` subagent (`run_in_background: false`
unless asked otherwise):

```text
Full Repository Path: /home/zyzto/Documents/Code/Hisab
Diff: branch changes
```

Use `uncommitted changes` when the user only wants the dirty working tree.
Summarize findings in a compact Severity / Location / Finding table. **Do not
auto-fix** unless asked.

Also follow [SECURITY.md](../../../SECURITY.md).

## 5. Tests

```bash
flutter test
```

Do **not** start a long-lived app or `flutter run`.

## 6. Contract and docs

If a change touches `packages/hisab_backend`, treat it as a breaking API change
for every backend implementation, including the private one. Update
`packages/hisab_backend/README.md` and `docs/BACKEND_BEHAVIOUR.md` in the same
change, and tell the user the private repo needs a matching update.

## 7–8. Release (only when asked)

1. Bump `pubspec.yaml` version (`+BUILD` always increments)
2. Commit with `chore(release): vX.Y.Z` (user must have asked to commit/release)
3. `git push origin main`
4. `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z`
5. `gh run watch` on the Release workflow until Checks, Build FOSS APKs and GitHub Release succeed

The release is created as a **draft** on purpose. The private pipeline attaches
the cloud build to the same release; publish only after both sets of artifacts
are present.

Never force-push tags or main. Never skip hooks unless the user insists.

## Output format

Keep the user-facing summary short:

1. Pass/fail for security, infra and offline-guard scripts
2. Security-review finding count (table if any)
3. Test result
4. If releasing: tag URL + Actions run URL + whether the draft is ready to publish
