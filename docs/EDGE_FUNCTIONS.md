# Supabase Edge Functions

The **source of truth** for Edge Function code is this repo. Deploy with the Supabase CLI to keep the project in sync.

## Functions in this repo

| Function | Path | Purpose |
|----------|------|--------|
| **invite-redirect** | `supabase/functions/invite-redirect/index.ts` | Validates invite token via `get_invite_by_token`, then 302 redirects to `redirect.html?token=...` (or error). Uses `SITE_URL` (default e.g. hisab.shenepoy.com) for the redirect base. |
| **og-invite-image** | `supabase/functions/og-invite-image/` | GET `?token=...` → returns a 1200×630 PNG with themed QR code (encoding the invite URL), “Hisab” branding, and logo. Used as `og:image` / `twitter:image` for invite link previews (WhatsApp, Telegram, etc.). Uses `SITE_URL`. Deploy with `--no-verify-jwt`. |
| **send-notification** | `supabase/functions/send-notification/index.ts` | Called by DB trigger `notify_group_activity()` (expenses + member_joined). Sends FCM push to other group members only; for `member_joined` the actor (new member) is never sent a notification. Requires secrets: `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_KEY`. |
| **telemetry** | `supabase/functions/telemetry/index.ts` | POST body `{ event, timestamp?, data? }`; inserts into `public.telemetry`. Used for optional anonymous usage analytics when enabled in app settings. |

## Deploy

From the project root:

```bash
supabase functions deploy invite-redirect --no-verify-jwt
supabase functions deploy og-invite-image --no-verify-jwt
supabase functions deploy send-notification --no-verify-jwt
supabase functions deploy telemetry --no-verify-jwt
```

Set Edge Function secrets in the dashboard (e.g. `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_KEY` for send-notification; `SITE_URL` for invite-redirect and og-invite-image if different from default).

## Firebase Cloud Function (invite redirect page with OG meta)

The path `/functions/v1/invite-redirect` is served by a **Firebase Cloud Function** (`inviteRedirectPage`) so that crawlers receive HTML with dynamic `og:image` and `twitter:image` pointing to the Supabase `og-invite-image` Edge Function for the token. See `functions/` and `firebase.json` (hosting rewrites). Deploy with `firebase deploy --only functions`; set `SUPABASE_URL` and `SITE_URL` via `functions/.env` or params (see `functions/.env.example`).

**Note (Spark plan):** The CI workflow deploys only Firebase Hosting and does not deploy this Cloud Function, so the project can stay on the free Spark plan. Invite redirect for crawlers (OG meta) is therefore not available unless you upgrade to Blaze and run `firebase deploy --only functions` manually.

## Syncing from Supabase

To pull the currently deployed code for a function (e.g. to compare or restore):

- Use Supabase MCP: `get_edge_function` with `project_id` and `function_slug`.
- Or Supabase CLI (if available): `supabase functions download <slug>`.

Keep this repo as the canonical source and deploy after changes so that production matches.
