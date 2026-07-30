# Edge Functions

<!-- markdownlint-disable MD060 -->

Function source lives in this repo under `supabase/functions/`. Deploy with the Supabase CLI so hosted projects stay in sync with git.

Local smoke tests: [LOCAL_TEST_ENV.md](LOCAL_TEST_ENV.md).

## Functions in this repo

| Function | Path | Purpose |
|----------|------|--------|
| **invite-redirect** | `supabase/functions/invite-redirect/index.ts` | Validates invite token via `get_invite_by_token`, then 302 redirects to `redirect.html?token=...` (or error). Uses `SITE_URL` (default e.g. hisab.shenepoy.com) for the redirect base. |
| **og-invite-image** | `supabase/functions/og-invite-image/` | GET `?token=...` → returns a 1200×630 PNG with themed QR code (encoding the invite URL), “Hisab” branding, and logo. Used as `og:image` / `twitter:image` for invite link previews (WhatsApp, Telegram, etc.). Uses `SITE_URL`. Deploy with `--no-verify-jwt`. |
| **send-notification** | `supabase/functions/send-notification/index.ts` | Called by DB trigger `notify_group_activity()` on expense insert/content-update/delete and member join. Copy: title = group name; body = `{title} - {cost}` with Edit/Deleted prefixes (en/ar). Skips image-only expense updates (create-with-photos). Inserts `user_notifications` for other members, then FCM when secrets are set. Actor is never notified. Dry-run still persists history. Secrets: `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_KEY`. |
| **telemetry** | `supabase/functions/telemetry/index.ts` | POST body `{ event, timestamp?, data? }`; inserts into `public.telemetry`. Used for optional anonymous usage analytics when enabled in app settings. |

## Local testing

Use the fuller local stack (Supabase + Edge Functions gateway + optional Firebase Functions emulator):

```bash
./scripts/local_test_env.sh up
./scripts/local_test_env.sh test-edge
```

See [LOCAL_TEST_ENV.md](LOCAL_TEST_ENV.md). Locally, `send-notification` returns `{ dry_run: true }` when FCM secrets are not set (no real push) but still inserts `user_notifications` for recipients. `SITE_URL` defaults to `http://localhost:8080` via `[edge_runtime.secrets]` in `supabase/config.toml`.

## Deploy

From the project root:

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
