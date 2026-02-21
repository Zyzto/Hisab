# Configuration

Hisab uses **Supabase** for authentication, database, and edge functions. Local data is stored in **SQLite** (via the PowerSync package) for offline use. All configuration is provided at build time via `--dart-define` — no secrets are committed to the repository.

For the full backend setup guide (creating the Supabase project, applying migrations, deploying edge functions), see [SUPABASE_SETUP.md](SUPABASE_SETUP.md).

---

## Quick Start

### Running with Supabase (online mode)

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
```

With a custom domain for invite links and/or correct email verification redirect (optional). Use the same domain as your web app (e.g. Firebase custom domain) so invite links look like `https://hisab.shenepoy.com/functions/v1/invite-redirect?token=...`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=INVITE_BASE_URL=https://hisab.shenepoy.com \
  --dart-define=SITE_URL=https://hisab.shenepoy.com
```

`SITE_URL` is used as the redirect URL in magic links and sign-up confirmation emails. If unset, Supabase uses the project **Site URL** from the dashboard (often localhost in dev). Add the same URL to **Supabase Dashboard → Authentication → URL Configuration → Redirect URLs**.

### Running without Supabase (offline only)

```bash
flutter run
```

The app works fully offline with no configuration. Authentication, sync, invites, and telemetry are disabled.

---

## Configuration Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `SUPABASE_URL` | For online mode | Your Supabase project URL (e.g. `https://xxxxx.supabase.co`) |
| `SUPABASE_ANON_KEY` | For online mode | Your Supabase anon/public key (starts with `eyJ...`) |
| `INVITE_BASE_URL` | Optional | Custom base URL for invite links (e.g. `https://hisab.shenepoy.com`). When set, share links and QR codes use this instead of the Supabase URL. The web app proxies `/functions/v1/invite-redirect` to Supabase. See [Invite links with a custom domain](#invite-links-with-a-custom-domain). |
| `SITE_URL` | Optional | Redirect URL for auth emails (magic link, sign-up confirmation). When set (e.g. `https://hisab.shenepoy.com`), verification and magic links in emails point here instead of the Supabase default (e.g. localhost). Must be in Supabase **Redirect URLs**. |
| `FCM_VAPID_KEY` | Optional | VAPID key for Firebase Cloud Messaging on web (Web Push certificates in Firebase Console). Required for web push token. |

**Push notifications (FCM):** The app receives push notifications when other group members add/edit expenses or join a group. Backend setup (Supabase trigger, Vault, Edge Function `send-notification`, FCM secrets) is in [SUPABASE_SETUP.md](SUPABASE_SETUP.md) (Section 5 and “Push notifications: end-to-end flow and verification”). In the app, notifications are enabled in Settings (online mode only); on web, `FCM_VAPID_KEY` must be set at build time for token registration.

Find these values in:
- **Supabase**: Dashboard → Settings → API

---

## Invite links with a custom domain

Invite links normally use your Supabase project URL (e.g. `https://xxxxx.supabase.co/functions/v1/invite-redirect?token=...`). To use your **web app’s domain** (e.g. `https://hisab.shenepoy.com/functions/v1/invite-redirect?token=...`) so shared links match your brand:

1. **Web app (Firebase Hosting or similar)**  
   The Flutter web app is served from your custom domain (e.g. hisab.shenepoy.com). It handles the path `/functions/v1/invite-redirect` by immediately redirecting the browser to the Supabase Edge Function. No Supabase Custom Domain is required.

2. **App**  
   Build/run with the same URL as your web app for the invite base:
   ```bash
   --dart-define=INVITE_BASE_URL=https://hisab.shenepoy.com
   ```
   Share links and QR codes will use this URL. When a user opens the link, they hit your domain first, then the app redirects to Supabase for token validation; Supabase then redirects back to your domain’s `redirect.html` (set `SITE_URL` in Supabase Edge Function secrets to the same domain).

**Alternative: Supabase Custom Domain**  
If you prefer a separate subdomain for invite links (e.g. `https://invite.yourdomain.com`) without the web app proxy, use [Supabase Custom Domains](https://supabase.com/docs/guides/platform/custom-domains) (paid plan) and set `INVITE_BASE_URL` to that subdomain.

---

## App Modes

### Local-Only Mode (default)

- Everything works locally with zero restrictions.
- Groups, participants, expenses, settlement — all fully functional.
- No sign-in required, no network calls.

### Online Mode

- Requires Supabase configuration and user sign-in.
- Data is written to Supabase and cached locally.
- If connectivity is temporarily lost, expenses can still be added (queued for later push).
- Invites and member management require an active connection.

### Switching Modes

- **Local → Online**: When disabling "Local Only" in settings, the app signs you in and migrates your local data to Supabase.
- **Online → Local**: When enabling "Local Only", the app disconnects. Your cached data remains available locally.

---

## IDE Launch Configuration

### VS Code / Cursor

Add to `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Hisab (Online)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=SUPABASE_URL=https://xxxxx.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=eyJhbGci..."
      ]
    },
    {
      "name": "Hisab (Offline Only)",
      "request": "launch",
      "type": "dart"
    }
  ]
}
```

---

## Web-Specific Notes

### OPFS for Better Performance

For faster SQLite performance on web, serve with these headers:

```bash
flutter run -d chrome \
  --web-header "Cross-Origin-Opener-Policy=same-origin" \
  --web-header "Cross-Origin-Embedder-Policy=require-corp"
```

Without these headers, the database falls back to IndexedDB (slower but compatible).

### Web SQLite

The `web/sqlite3.wasm` file is required for SQLite on web. If missing, run:

```bash
dart run powersync:setup_web
```

---

## Feature Availability

| Feature | Local-Only | Online (Connected) | Online (Temporarily Offline) |
|---------|------------|-------------------|------------------------------|
| Create groups, participants, expenses | Yes | Yes | Expenses only (queued) |
| Record settlement | Yes | Yes | Queued for later push |
| Local data persistence | Yes | Yes | Yes |
| Authentication (email, OAuth) | No | Yes | N/A |
| Cloud sync across devices | No | Yes | Reconnects automatically |
| Group invites | No | Yes | Requires connectivity |
| Member management | No | Yes | Requires connectivity |
| Telemetry | No | Yes | No |
| Export/import backup | Yes | Yes | Yes |

---

## Connection Status Indicators (Online Mode)

When in Online mode, a status icon appears in the top-right corner:

| Icon | Meaning |
|------|---------|
| 🟢 Cloud | Connected and synced |
| 🔄 Spinner | Syncing in progress |
| 🔴 Cloud-off | Temporarily offline |

The icon is hidden entirely in Local-Only mode.

---

## Firebase Hosting (web)

Firebase Hosting serves **static files** only. It does not run your app or provide environment variables at runtime. Any "secrets" (Supabase URL, anon key, etc.) must be **injected at build time** via `--dart-define`; the resulting JavaScript will contain those values. The Supabase **anon key** is intended for client use and is protected by Row Level Security (RLS); do not put the service-role key in the client.

### 1. Build the web app with your config

Set `SITE_URL` to your Firebase Hosting URL so auth redirects (magic link, email confirmation) land on your live site. Add that same URL in **Supabase Dashboard → Authentication → URL Configuration → Redirect URLs**.

```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=INVITE_BASE_URL=https://hisab.shenepoy.com \
  --dart-define=SITE_URL=https://hisab.shenepoy.com
```

If you use the default Firebase URL instead of a custom domain, use that for `SITE_URL` (e.g. `https://YOUR_PROJECT.web.app`) and add it to Supabase redirect URLs.

### 2. Deploy

Include the static privacy policy page so `https://YOUR_PROJECT.web.app/privacy` is available (e.g. for Play Console):

```bash
cp -r web/privacy build/web/
firebase deploy --only hosting
```

Your `firebase.json` already points `hosting.public` to `build/web`, so the built output (including `privacy/index.html`) is deployed as-is.

### 3. Keeping secrets out of your shell history

- **Option A – CI (recommended)**  
  Use GitHub Actions (or similar) and store `SUPABASE_URL` and `SUPABASE_ANON_KEY` as **repository secrets**. In the workflow, run the same `flutter build web --dart-define=...` using `${{ secrets.SUPABASE_URL }}` (and the anon key), then run `firebase deploy --only hosting` using a Firebase token (e.g. `FIREBASE_TOKEN` from `firebase login:ci`). The build and deploy happen in CI; you never type secrets locally.

- **Option B – Local script**  
  Put the build command in a script that reads from env vars (e.g. `SUPABASE_URL`, `SUPABASE_ANON_KEY`) and passes them to `--dart-define`. Source the vars from a file that is gitignored (e.g. `.env.production`) so you don't commit them. Never commit that file or the script's contents with real keys.

- **Option C – One-off**  
  Run the `flutter build web --dart-define=...` command once locally and then deploy. Keys will be in your shell history unless your shell is configured not to persist it.

After the first deploy, get your live URL from the Firebase console (e.g. `https://YOUR_PROJECT.web.app`) and add it to Supabase redirect URLs if you didn't use `SITE_URL` in the initial build.

---

## Troubleshooting

### App works offline but nothing syncs

- Verify both `--dart-define` parameters are set correctly.
- Check Supabase project status in the dashboard.

### OAuth redirect issues

- **Mobile**: Ensure the app scheme (`io.supabase.hisab`) is registered in Android/iOS config.
- **Web**: Verify the redirect URL is in Supabase Authentication → URL Configuration → Redirect URLs.
- Add `http://localhost:*` to Supabase redirect URLs for local development.

### "RLS policy violation" errors

- Ensure the user is authenticated.
- Verify the user has the correct role for the operation.
- For new group creation, `owner_id` must match `auth.uid()`.

### Migration fails when switching to online

- Ensure you have a stable internet connection.
- Try again — the migration is idempotent (uses upserts).
