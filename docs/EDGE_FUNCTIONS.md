# Edge Functions

<!-- markdownlint-disable MD060 -->

Function source lives in this repo under `supabase/functions/`. Deploy with the Supabase CLI so hosted projects stay in sync with git.

Local smoke tests: [LOCAL_TEST_ENV.md](LOCAL_TEST_ENV.md).

Shared helpers: `supabase/functions/_shared/` (CORS, JSON responses, telemetry validation).

## Auth modes

| Function | Caller | Platform `verify_jwt` | In-function auth |
|----------|--------|----------------------|------------------|
| **telemetry** | Flutter app (optional analytics) | `false` ([config.toml](../supabase/config.toml)) | Require `apikey` == anon key; insert with **anon** client so RLS applies |
| **send-notification** | `pg_net` from `notify_group_activity()` | `false` | `Authorization: Bearer` must equal service role key |
| **invite-redirect** | Public invite links / Hosting proxy | `false` | Invite `token` query param; fail closed on RPC errors |
| **og-invite-image** | Link-preview crawlers | `false` | Token shape guard only |

Official patterns: [Securing Edge Functions](https://supabase.com/docs/guides/functions/auth), [Authorization headers](https://supabase.com/docs/guides/functions/auth-headers).

## Functions in this repo

| Function | Path | Purpose |
|----------|------|--------|
| **invite-redirect** | `supabase/functions/invite-redirect/index.ts` | Validates invite token via `get_invite_by_token`, then 302 redirects to `redirect.html?token=...` (or `error=expired` / `missing`). Uses `SITE_URL` for the redirect base. Fail closed if DB/RPC fails. |
| **og-invite-image** | `supabase/functions/og-invite-image/` | GET `?token=...` → 1200×630 PNG with themed QR (invite URL), branding, logo. Used as `og:image` / `twitter:image`. |
| **send-notification** | `supabase/functions/send-notification/index.ts` | Called by DB trigger `notify_group_activity()` on expense insert/content-update/delete and member join. Persists `user_notifications` for other members, then FCM. Excludes actor by `user_id` and by shared FCM token string. FCM `data` includes `actor_user_id` and `group_id`. Caches FCM OAuth token; sends with bounded concurrency. Dry-run still persists history. Secrets: `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_KEY`. |
| **telemetry** | `supabase/functions/telemetry/index.ts` | POST `{ event, timestamp?, data? }` with `apikey`; validates payload (mirrors RLS) and inserts via anon client into `public.telemetry`. |

SQL helpers related to notifications:

- `claim_device_token(token, platform, locale)` — exclusive FCM token ownership (`UNIQUE(device_tokens.token)`).
- `notify_group_activity()` — skips `pg_net` when the actor is the only group member (and for personal groups / suppress / image-only updates).

## Local testing

Use the fuller local stack (Supabase + Edge Functions gateway + optional Firebase Functions emulator):

```bash
./scripts/local_test_env.sh up
./scripts/local_test_env.sh test-edge
```

See [LOCAL_TEST_ENV.md](LOCAL_TEST_ENV.md). Locally, `send-notification` returns `{ dry_run: true }` when FCM secrets are not set (no real push) but still inserts `user_notifications` for recipients. `SITE_URL` defaults to `http://localhost:8080` via `[edge_runtime.secrets]` in `supabase/config.toml`.

## Deploy

From the project root (`verify_jwt` is also set in `supabase/config.toml`):

```bash
supabase functions deploy invite-redirect --no-verify-jwt
supabase functions deploy og-invite-image --no-verify-jwt
supabase functions deploy send-notification --no-verify-jwt
supabase functions deploy telemetry --no-verify-jwt
```

Set Edge Function secrets in the dashboard (e.g. `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_KEY` for send-notification; `SITE_URL` for invite-redirect and og-invite-image if different from default).

## Invite redirect on Firebase Hosting (Spark / free plan)

On the free Spark plan, the path `/functions/v1/invite-redirect` is served by **static** `invite-redirect.html` (see `firebase.json` hosting rewrites). CI builds this file from `web/invite-redirect-template.html` (substituting `SUPABASE_URL`) and copies `web/redirect.html` to the Hosting output. That static page redirects the browser to the Supabase `invite-redirect` Edge Function, which validates the token and redirects to `redirect.html`. No Firebase Cloud Function is required; invite links work on the free plan.

## Firebase Cloud Function (optional; invite redirect page with OG meta)

The same path can optionally be served by a **Firebase Cloud Function** (`inviteRedirectPage`) so that crawlers receive HTML with dynamic `og:image` and `twitter:image` pointing to the Supabase `og-invite-image` Edge Function for the token. See `functions/` and `firebase.json` (hosting rewrites). Deploy with `firebase deploy --only functions`; set `SUPABASE_URL` and `SITE_URL` via `functions/.env` or params (see `functions/.env.example`).

**Note (Spark plan):** The CI workflow deploys only Firebase Hosting and does not deploy this Cloud Function, so the project can stay on the free Spark plan. Invite redirect (token validation and `redirect.html`) works via the static flow above. Dynamic OG meta for crawlers is only available if you upgrade to Blaze and run `firebase deploy --only functions` manually.

## Syncing from Supabase

To pull the currently deployed code for a function (e.g. to compare or restore):

- Use Supabase MCP: `get_edge_function` with `project_id` and `function_slug`.
- Or Supabase CLI (if available): `supabase functions download <slug>`.

Keep this repo as the canonical source and deploy after changes so that production matches.
