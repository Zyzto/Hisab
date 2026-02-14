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

With a custom domain for invite links and/or correct email verification redirect (optional):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=INVITE_BASE_URL=https://invite.yourdomain.com \
  --dart-define=SITE_URL=https://yourdomain.com
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
| `INVITE_BASE_URL` | Optional | Custom base URL for invite links (e.g. `https://invite.yourdomain.com`). When set, share links and QR codes use this instead of the Supabase URL. See [Invite links with a custom domain](#invite-links-with-a-custom-domain). |
| `SITE_URL` | Optional | Redirect URL for auth emails (magic link, sign-up confirmation). When set (e.g. `https://yourdomain.com`), verification and magic links in emails point here instead of the Supabase default (e.g. localhost). Must be in Supabase **Redirect URLs**. |

Find these values in:
- **Supabase**: Dashboard → Settings → API

---

## Invite links with a custom domain

Invite links normally use your Supabase project URL (e.g. `https://xxxxx.supabase.co/functions/v1/invite-redirect?token=...`). To show your own domain (e.g. `https://invite.yourdomain.com/functions/v1/invite-redirect?token=...`) **without running your own server**, use Supabase’s **Custom Domain** and the app’s optional `INVITE_BASE_URL`:

1. **Supabase (paid plan)**  
   In the [Supabase Dashboard](https://supabase.com/dashboard): **Project → Settings → Custom Domains** (or [Add-ons](https://supabase.com/docs/guides/platform/custom-domains)). Add a subdomain (e.g. `invite.yourdomain.com`), add the CNAME and TXT records at your DNS provider, then verify and activate. Your Edge Functions (including `invite-redirect`) are then available at that domain.

2. **App**  
   Build/run with the same URL as the invite base:
   ```bash
   --dart-define=INVITE_BASE_URL=https://invite.yourdomain.com
   ```
   Share links and QR codes will use this URL. The redirect still hits the same Supabase Edge Function; no extra hosting is required.

If you prefer to use the custom domain for all Supabase traffic (Auth, API, Edge Functions), you can set `SUPABASE_URL` to your custom domain instead and omit `INVITE_BASE_URL`. See [Supabase Custom Domains](https://supabase.com/docs/guides/platform/custom-domains).

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

Firebase Hosting serves **static files** only. It does not run your app or provide environment variables at runtime. Any “secrets” (Supabase URL, anon key, etc.) must be **injected at build time** via `--dart-define`; the resulting JavaScript will contain those values. The Supabase **anon key** is intended for client use and is protected by Row Level Security (RLS); do not put the service-role key in the client.

### 1. Build the web app with your config

Set `SITE_URL` to your Firebase Hosting URL so auth redirects (magic link, email confirmation) land on your live site. Add that same URL in **Supabase Dashboard → Authentication → URL Configuration → Redirect URLs**.

```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=SITE_URL=https://YOUR_PROJECT.web.app
```

Optional: if you use a custom domain for Hosting, use that for `SITE_URL` and add it to Supabase redirect URLs.

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
  Put the build command in a script that reads from env vars (e.g. `SUPABASE_URL`, `SUPABASE_ANON_KEY`) and passes them to `--dart-define`. Source the vars from a file that is gitignored (e.g. `.env.production`) so you don’t commit them. Never commit that file or the script’s contents with real keys.

- **Option C – One-off**  
  Run the `flutter build web --dart-define=...` command once locally and then deploy. Keys will be in your shell history unless your shell is configured not to persist it.

After the first deploy, get your live URL from the Firebase console (e.g. `https://YOUR_PROJECT.web.app`) and add it to Supabase redirect URLs if you didn’t use `SITE_URL` in the initial build.

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
