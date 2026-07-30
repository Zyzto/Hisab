---
name: hisab-release-checks
description: >-
  Run Hisab pre-release security and infra checks (static scripts, Supabase
  advisors, security-review subagent, tests, tag/CI watch). Use when the user
  asks for a security check, infra check, release gate, release double-check,
  bump release, push tag, or to verify CI before/after shipping.
---

# Hisab release checks

Pre-release / post-change gate for the Hisab Flutter + Supabase + Firebase repo.

**Do not start the app** (`never run project` user rule). Prefer scripts + MCP + CI.

## When to run

- User asks for **security check**, **infra check**, **release checks**, or **double-check** before ship
- User asks to **bump release**, **push tag**, or **make sure CI succeeds**
- After migrations / Edge Function / Hosting / secrets-related changes

## Fixed project facts

| Item | Value |
|------|--------|
| Supabase project ref | `jscbwcerbsdewsczadjf` (Hisab_01) |
| Release workflow | `.github/workflows/release.yml` (tags `v*`) |
| Version | `pubspec.yaml` → `MARKETING+BUILD` (e.g. `0.6.16+65`) |
| Tag style | `v0.6.16` annotated; commit `chore(release): v0.6.16` |

## Checklist (copy and track)

```
Release checks:
- [ ] 1. Static security (`verify_security.sh`)
- [ ] 2. Static infra (`verify_infra.sh`)
- [ ] 3. Security review subagent (diff)
- [ ] 4. Supabase advisors (security + performance)
- [ ] 5. Migration / Edge Function sync (if touched)
- [ ] 6. flutter test (and note online tests run in CI)
- [ ] 7. Docs touch-up if behavior changed
- [ ] 8. Version bump + commit (only if user asked to release)
- [ ] 9. Push + tag + watch CI (only if user asked)
```

## 1–2. Static scripts (always)

From repo root:

```bash
bash ./scripts/run_release_checks.sh
# or separately:
bash ./scripts/verify_security.sh
bash ./scripts/verify_infra.sh
```

Fix failures before continuing. These same scripts run as CI jobs **Security Check** and **Infra Check**.

**Before any `git push`:** ensure hooks are installed (`bash ./scripts/install_git_hooks.sh`). `.githooks/pre-push` and `.cursor/hooks/block-push-if-secrets.sh` both run `verify_security.sh` against the commit tree. Do not use `--no-verify` unless the user explicitly asks.

## 3. Security review subagent

Launch exactly one `security-review` subagent (`run_in_background: false` unless asked otherwise):

```text
Full Repository Path: /home/zyzto/Documents/Code/Hisab
Diff: branch changes
```

Use `uncommitted changes` when the user only wants the dirty working tree. After it finishes, summarize findings in a compact Severity / Location / Finding table. **Do not auto-fix** unless the user asks.

Also follow [SECURITY.md](../../../SECURITY.md) and the built-in `/review-security` skill patterns.

## 4. Supabase advisors (live infra/security)

Discover Supabase MCP (`GetMcpTools` pattern `supabase` / `get_advisors`). Then:

1. `list_projects` → confirm ref `jscbwcerbsdewsczadjf`
2. `get_advisors` with `type: "security"`
3. `get_advisors` with `type: "performance"`
4. Optionally `list_migrations` — remote versions must include every file under `supabase/migrations/`
5. Optionally `list_edge_functions` — expect `invite-redirect`, `og-invite-image`, `send-notification`, `telemetry` ACTIVE

Report ERROR/WARN advisors. Do not apply migrations or deploy Edge Functions unless the user explicitly asks.

If MCP is unavailable or unauthenticated, say so and continue with static checks + security-review; do not invent advisor results.

## 5. Migration / Edge coupling

When notification or backend copy changes:

- Migration + `supabase/functions/send-notification` must ship together
- Prefer CLI `supabase functions deploy … --no-verify-jwt` when logged in; else MCP `deploy_edge_function` with `verify_jwt: false` for functions that use service-role header auth (`send-notification`)

## 6. Tests

```bash
flutter test
```

Do **not** start a long-lived app/`flutter run`. Online integration tests run in CI (`test-online`).

## 7. Docs

If behavior changed, update the relevant docs (`docs/SUPABASE_SETUP.md`, `EDGE_FUNCTIONS.md`, `CODEBASE.md`, `SECURITY.md`, etc.). Prefer editing existing docs over new files.

## 8–9. Release (only when asked)

1. Bump `pubspec.yaml` version (`+BUILD` always increments for Play)
2. Commit with `chore(release): vX.Y.Z` (user must have asked to commit/release)
3. `git push origin main`
4. `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z`
5. Watch: `gh run watch` on the Release workflow until all jobs succeed (Security Check, Infra Check, Test, Online Tests, Build Android, Deploy Web, GitHub Release, Deploy to Google Play)

Never force-push tags/main. Never skip hooks unless the user insists.

## Output format

Keep the user-facing summary short:

1. Pass/fail for Security + Infra scripts
2. Security-review finding count (table if any)
3. Advisor ERROR/WARN highlights (or “MCP unavailable”)
4. Test result
5. If releasing: tag URL + Actions run URL + final green/red
