# Security and Secret Management

This repository is public. Follow these rules for all contributions.

## Safe to Commit

- `supabase/config.toml` (with `env(...)` placeholders only)
- `supabase/migrations/*.sql`
- `supabase/seed.sql` with local test-only data (fake users)
- `supabase/functions/**` source code
- Documentation and scripts that reference secret names (not secret values)

## Never Commit

- Supabase `service_role` key
- Supabase JWT signing keys / `signing_keys.json`
- Environment-specific `anon` keys (even though they are public/client keys) unless intentionally documented for a public demo
- Firebase service account JSON private keys
- OAuth client secrets (Google, GitHub, Apple, etc.)
- SMTP/API tokens and any `.env*` files with real values
- Real user data exports or production database dumps

## Where Secrets Should Live

- Local development: environment variables or untracked local files.
- CI/CD: GitHub Actions Secrets (or your platform secret manager).
- Supabase Edge Functions: `supabase secrets set ...`.
- Supabase local config: use `env(NAME)` placeholders in `supabase/config.toml`.

## Public Repo Notes

- Keep local integration test users in `supabase/seed.sql` non-production only.
- Never reuse seeded test credentials in any live environment.
- If a secret is committed accidentally, rotate it immediately and remove it from git history.

## Config-as-Code Guard

Run this before PRs:

```bash
bash ./scripts/verify_supabase_config_as_code.sh
```

This verifies required Supabase config files are present and tracked.
