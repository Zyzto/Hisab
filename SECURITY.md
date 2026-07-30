# Security and secrets

This repository is **public**. Treat every commit as visible to the world.

## Safe to commit

- `supabase/config.toml` with `env(...)` placeholders only
- `supabase/migrations/*.sql`
- `supabase/seed.sql` with **fake** local test users only
- `supabase/functions/**` source (no embedded keys)
- Docs and scripts that name secrets — never their values
- `*_example.json` / `*.env.example` templates

## Never commit

- Supabase `service_role` key or JWT signing material (`signing_keys.json`)
- Filled `anon` keys / project URLs in tracked files (use local define files)
- Firebase service-account JSON (private keys)
- OAuth client secrets, SMTP/API tokens, real `.env*` values
- Production dumps or real user exports

**Gitignored paths — do not `git add -f`:**

| Path | Why |
|------|-----|
| `dart_defines_local.json` / `dart_defines_online.json` | Project URLs + keys |
| `lib/core/constants/app_secrets.dart` | App secrets |
| `secrets/**` (except `README.md` / `.gitkeep`) | FCM SA JSON, etc. |
| `supabase/.env` / `functions/.env` | Local Edge / redirect env |
| `android/app/google-services.json` | Firebase Android |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS |
| `**/fcm-service-account*.json` | Firebase Admin private key |

Copy from `*_example` templates and [secrets/README.md](secrets/README.md).

## Where secrets live

| Context | Store in |
|---------|----------|
| Local dev | Env vars or untracked files (table above) |
| CI/CD | [GitHub Actions secrets](docs/GITHUB_ACTIONS_SECRETS.md) |
| Edge (hosted) | `supabase secrets set ...` |
| Local config.toml | `env(NAME)` placeholders only |
| Local FCM for Edge | `secrets/fcm-service-account.test.json` → `./scripts/local_test_env.sh reload-secrets` |

## If something leaks

Rotate the credential immediately and remove it from git history. Seeded test users in `supabase/seed.sql` must never be reused in production.

## Config-as-code / release checks

Before opening a PR that touches Supabase config, or before a release:

```bash
bash ./scripts/run_release_checks.sh
```

Runs:

| Script | What it gates |
|--------|----------------|
| [`scripts/verify_security.sh`](scripts/verify_security.sh) | No tracked secret paths; no PEM/JWT/API keys/tokens/service_role literals; Firebase web placeholders |
| [`scripts/verify_infra.sh`](scripts/verify_infra.sh) | Config-as-code, Edge Function sources, Firebase Hosting, web shell, version/CI pins |

CI runs the same two checks as **Security Check** and **Infra Check** jobs on tag releases (`.github/workflows/release.yml`). Agent workflow: [`.cursor/skills/hisab-release-checks/SKILL.md`](.cursor/skills/hisab-release-checks/SKILL.md) (also runs Supabase advisors + security-review when asked).

Config-as-code only:

```bash
bash ./scripts/verify_supabase_config_as_code.sh
```

## Before push (secret scan)

Pushes are blocked if the commit tree contains sensitive material.

1. **Install git hooks once per clone** (sets `core.hooksPath=.githooks`):

```bash
bash ./scripts/install_git_hooks.sh
```

2. **`.githooks/pre-push`** runs `HISAB_SCAN_TREE=<sha> ./scripts/verify_security.sh` for every ref being pushed.

3. **Cursor agent pushes** are also gated by [`.cursor/hooks.json`](.cursor/hooks.json) (`beforeShellExecution` → `block-push-if-secrets.sh`).

Bypass only when you intentionally must (not for real secrets):

```bash
git push --no-verify
```
