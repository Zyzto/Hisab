# Supabase Edge Functions

The **source of truth** for Edge Function code is this repo. Deploy with the Supabase CLI to keep the project in sync.

## Functions in this repo

| Function | Path | Purpose |
|----------|------|--------|
| **invite-redirect** | `supabase/functions/invite-redirect/index.ts` | Validates invite token via `get_invite_by_token`, then 302 redirects to `redirect.html?token=...` (or error). Uses `SITE_URL` (default e.g. hisab.shenepoy.com) for the redirect base. |
| **send-notification** | `supabase/functions/send-notification/index.ts` | Called by DB trigger `notify_group_activity()` (expenses + member_joined). Sends FCM push to other group members only; for `member_joined` the actor (new member) is never sent a notification. Requires secrets: `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_KEY`. |
| **telemetry** | `supabase/functions/telemetry/index.ts` | POST body `{ event, timestamp?, data? }`; inserts into `public.telemetry`. Used for optional anonymous usage analytics when enabled in app settings. |

## Deploy

From the project root:

```bash
supabase functions deploy invite-redirect --no-verify-jwt
supabase functions deploy send-notification --no-verify-jwt
supabase functions deploy telemetry --no-verify-jwt
```

Set Edge Function secrets in the dashboard (e.g. `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_KEY` for send-notification; `SITE_URL` for invite-redirect if different from default).

## Syncing from Supabase

To pull the currently deployed code for a function (e.g. to compare or restore):

- Use Supabase MCP: `get_edge_function` with `project_id` and `function_slug`.
- Or Supabase CLI (if available): `supabase functions download <slug>`.

Keep this repo as the canonical source and deploy after changes so that production matches.
