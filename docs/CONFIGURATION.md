# Configuration

<!-- markdownlint-disable MD031 MD032 MD034 MD060 -->

Hisab is **offline-first**: SQLite (PowerSync package) always runs on device. **Supabase** is optional — Auth, Postgres, RPCs, and Edge Functions when you pass build-time defines.

All secrets and project URLs come from `--dart-define` or gitignored define files. Nothing sensitive belongs in the repo — see [SECURITY.md](../SECURITY.md).

- Hosted backend setup → [SUPABASE_SETUP.md](SUPABASE_SETUP.md)
- Local Podman stack → [LOCAL_TEST_ENV.md](LOCAL_TEST_ENV.md)

---

## Quick Start

### Running with Supabase (online mode)

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
```

With a custom domain for invite links and/or correct email verification redirect (optional). Use the same domain as your web app (Firebase Hosting) so invite links look like `https://hisab.shenepoy.com/functions/v1/invite-redirect?token=...`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=INVITE_BASE_URL=https://hisab.shenepoy.com \
  --dart-define=SITE_URL=https://hisab.shenepoy.com
```

`SITE_URL` is used as the redirect URL in magic links and sign-up confirmation emails. If unset, Supabase uses the project **Site URL** from the dashboard (often localhost in dev). Add the same URL to **Supabase Dashboard → Authentication → URL Configuration → Redirect URLs**.

### Local Supabase (Docker / Podman)

```bash
./scripts/local_test_env.sh up
flutter run --dart-define-from-file=dart_defines_local.json --web-port=8080
```

See [LOCAL_TEST_ENV.md](LOCAL_TEST_ENV.md). Prefer VS Code launches **Hisab (Local Online)** / **Hisab (Chrome Local Online)**. Use `dart_defines_online.json` only for a hosted (non-local) project.

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
| `INVITE_BASE_URL` | Optional | Custom base URL for invite links (production: `https://hisab.shenepoy.com`). When set, share links and QR codes use this instead of the Supabase URL. The web app proxies `/functions/v1/invite-redirect` to Supabase. See [Invite links with a custom domain](#invite-links-with-a-custom-domain). |
| `SITE_URL` | Optional | Redirect URL for auth emails (magic link, sign-up confirmation) and web OAuth (`authRedirectUrl`). Production Firebase Hosting: `https://hisab.shenepoy.com`. When set, verification and magic links point here instead of the Supabase default (e.g. localhost). Must be in Supabase **Redirect URLs**. If `SITE_URL` is mistakenly `http://` while the page origin is `https://` on the same host, the web app upgrades the OAuth redirect to the current HTTPS origin (Hosting’s http→https 301 breaks PKCE otherwise). |
| `FCM_VAPID_KEY` | Optional | VAPID key for Firebase Cloud Messaging on web (Web Push certificates in Firebase Console). Required for web push token. |
| `FIREBASE_*` | Web only | Firebase web SDK options (`FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID`). No defaults are committed. **Debug:** provide via launch options using `--dart-define-from-file=dart_defines_online.json` (see example file). **CI:** GitHub Actions secrets are passed as `--dart-define` and injected into `web/index.html` and `web/firebase-messaging-sw.js` at build time. |
| `ENABLE_WEB_SEMANTICS` | Web only, optional | Enables `SemanticsBinding.instance.ensureSemantics()` at startup. Default is `false` because iOS Safari may show severe scroll/input jank when semantics is always enabled. Turn on only for accessibility-focused builds. |

**VSCode / development:** Copy `dart_defines_online.example.json` to `dart_defines_online.json` (gitignored). Put your real values only in `dart_defines_online.json`; the example file contains placeholders only. Fill in `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and optionally `FCM_VAPID_KEY` and all `FIREBASE_*` keys. For local dev, `INVITE_BASE_URL` and `SITE_URL` are set to `http://localhost:8080` so magic links and invite links open your dev app; the launch configs use `--web-port=8080` so the app always runs on that port. Add **http://localhost:8080** to **Supabase Dashboard → Authentication → URL Configuration → Redirect URLs**. Use the **Hisab (Online)** or **Hisab (Chrome Web)** launch configuration. The Dart app reads Firebase config from these dart-defines; for **web** runs, `web/index.html` and `web/firebase-messaging-sw.js` contain placeholders—replace them (e.g. with a local script that injects from `dart_defines_online.json`) before running web if you need FCM in debug, or rely on CI for production builds.

**Push notifications (FCM):** The app receives push notifications when other group members add/edit/delete expenses or join a group. Push title is the **group name**; body is `{expense title} - {amount}` with localized Edit/Deleted prefixes. Backend setup (Supabase trigger, Vault, Edge Function `send-notification`, FCM secrets) is in [SUPABASE_SETUP.md](SUPABASE_SETUP.md) (Section 5 and “Push notifications: end-to-end flow and verification”). Apply migration `20260730013835_notify_group_activity_revamp.sql` and redeploy `send-notification` together. In the app, notifications are enabled in Settings (online mode only); on web, `FCM_VAPID_KEY` must be set at build time for token registration. On iPhone/iPad (WebKit), push requires the installed Home Screen PWA — see [CODEBASE.md](CODEBASE.md) (Web and PWA).

Find these values in:
- **Supabase**: Dashboard → Settings → API

### Receipt AI (optional)

Configure under **Settings → Receipt / AI** (hidden on web). Scan mode:

| Mode | Behavior | Platforms |
|---|---|---|
| **Off** | Attach photo only | Android, iOS |
| **On device (OCR)** | Tesseract4Android (Tess 5) / Apple Vision (iOS) + local heuristics (vendor/date/total); bundled `eng`+`ara` tessdata (~5.5MB raw ≈ ~2.7MB packaged) on Android via `ReceiptOcrBridge` | Android, iOS |
| **Gemini Nano** | On-device Gemini via AI Core; Check device / Download in settings | Android only (AI Core); iOS falls back to OCR |
| **Cloud** | BYO **Gemini** or **OpenAI** vision; Hisab-managed cloud is reserved for later | Android, iOS |

API keys are **user-provided** and stored **only on the device**. They are not sent to Supabase or committed to the repo. If cloud keys are missing or Nano is unavailable, the app falls back to on-device OCR heuristics. Android `minSdk` is **26** (required for ML Kit GenAI Prompt / Nano).

---

## Invite links with a custom domain

Invite links normally use your Supabase project URL (e.g. `https://xxxxx.supabase.co/functions/v1/invite-redirect?token=...`). To use your **Firebase Hosting domain** (`https://hisab.shenepoy.com/functions/v1/invite-redirect?token=...`) so shared links match your brand:

1. **Web app (Firebase Hosting)**  
   The Flutter web app is served from the Hosting custom domain. It handles the path `/functions/v1/invite-redirect` by immediately redirecting the browser to the Supabase Edge Function. No Supabase Custom Domain is required.

2. **App**  
   Build/run with the same HTTPS origin (CI already passes the GitHub secret):
   ```bash
   --dart-define=INVITE_BASE_URL=https://hisab.shenepoy.com
   ```
   Share links and QR codes will use this URL. When a user opens the link, they hit Hosting first, then the app redirects to Supabase for token validation; Supabase then redirects back to the domain’s `redirect.html` (set `SITE_URL` in Supabase Edge Function secrets to the same HTTPS origin).

**Alternative: Supabase Custom Domain**  
If you prefer a separate subdomain for invite links without the web app proxy, use [Supabase Custom Domains](https://supabase.com/docs/guides/platform/custom-domains) (paid plan) and set `INVITE_BASE_URL` to that subdomain.

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

Committed [`.vscode/launch.json`](../.vscode/launch.json) already defines the Hisab launch configs (Online, Chrome Web, Local Online, Offline, etc.). Prefer those over hand-written `--dart-define` stubs.

Typical args use gitignored define files:

```bash
flutter run --dart-define-from-file=dart_defines_online.json --web-port=8080
flutter run --dart-define-from-file=dart_defines_local.json --web-port=8080
```

Copy `dart_defines_online.example.json` → `dart_defines_online.json` (and/or generate local defines via `./scripts/local_test_env.sh`).

---

## Web-Specific Notes

### Flutter default service worker deprecation

Flutter web is deprecating/removing the default `flutter_service_worker.js` behavior. This project uses a custom [`web/flutter_bootstrap.js`](../web/flutter_bootstrap.js) that calls `_flutter.loader.load()` without default service-worker settings, so web updates rely on normal browser/CDN caching behavior. Firebase compat SDKs load asynchronously in [`web/index.html`](../web/index.html); bootstrap waits on `window.__hisabFirebaseReady` before starting Flutter.

For context, see Flutter issue [#156910](https://github.com/flutter/flutter/issues/156910).

### iOS Safari performance and accessibility semantics

Flutter web accessibility semantics are opt-in for performance reasons. In this project, semantics are disabled by default on web to avoid known iOS Safari jank. If you need always-on screen reader semantics, build with:

```bash
flutter build web --dart-define=ENABLE_WEB_SEMANTICS=true
```

Use this only for accessibility-targeted builds because it can reduce scroll smoothness on iOS Safari.

Visual/interaction cheap-paths are **per surface** (iOS web vs Android web vs native), not blanket “all web”. See [`UiPerf`](../lib/core/platform/ui_perf.dart) and [WEB_IOS_SAFARI_PERFORMANCE.md](WEB_IOS_SAFARI_PERFORMANCE.md).

### OPFS for Better Performance

For faster SQLite performance on web, serve with these headers:

```bash
flutter run -d chrome \
  --web-header "Cross-Origin-Opener-Policy=same-origin" \
  --web-header "Cross-Origin-Embedder-Policy=require-corp"
```

Without these headers, the database falls back to IndexedDB (slower but compatible).

### Web SQLite

PowerSync on web requires `web/sqlite3.wasm` and `web/powersync_db.worker.js` in the `web/` folder. If you see errors like `Unexpected token '<'` for `powersync_db.worker.js` or `Incorrect response MIME type` for WASM, run:

```bash
flutter pub run powersync:setup_web
```

This downloads the WASM and single DB/sync worker into `web/` (and removes any obsolete `powersync_sync.worker.js`). Rebuild and redeploy so `build/web/` (and Firebase Hosting) serve them. `firebase.json` is configured to serve `*.wasm` with `Content-Type: application/wasm`.

---

## Feature Availability

| Feature | Local-Only | Online (Connected) | Online (Temporarily Offline) |
|---------|------------|-------------------|------------------------------|
| Create/edit local data (groups, participants, expenses, tags) | Yes | Yes | Queued and pushed on reconnect |
| Record settlement | Yes | Yes | Queued for later push |
| Local data persistence | Yes | Yes | Yes |
| Authentication (email, OAuth) | No | Yes | N/A |
| Cloud sync across devices | No | Yes | Reconnects automatically |
| Group invites | No | Yes | Requires connectivity |
| Member management | No | Yes | Requires connectivity |
| Telemetry | No | Yes | No |
| Profile dashboard (local KPIs / budgets) | Yes | Yes | Yes (cached) |
| In-app notification history (`user_notifications`) | No | Yes (synced) | Cached after sync |
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

Production web is on **Firebase Hosting** (`hisab-c8eb1`), custom domain **https://hisab.shenepoy.com** (also `https://hisab-c8eb1.web.app`). Set `SITE_URL` / `INVITE_BASE_URL` to that HTTPS origin so auth redirects (magic link, email confirmation, OAuth) and invite links land on the live site. Add the same URL in **Supabase Dashboard → Authentication → URL Configuration → Redirect URLs**. Prefer `https://` — Hosting redirects bare `http://` with a 301, which can break OAuth code exchange.

```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=INVITE_BASE_URL=https://hisab.shenepoy.com \
  --dart-define=SITE_URL=https://hisab.shenepoy.com \
  --dart-define=ENABLE_WEB_SEMANTICS=false \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=hisab-c8eb1 \
  # ... other FIREBASE_* as in dart_defines_online.example.json
```

### 2. Deploy

Include the static privacy and account-deletion pages in the Firebase Hosting deploy so `https://hisab.shenepoy.com/privacy` and `https://hisab.shenepoy.com/delete-account` are available (e.g. for Play Console):

```bash
cp -r web/privacy build/web/
cp -r web/delete-account build/web/
firebase deploy --only hosting
```

Your `firebase.json` already points `hosting.public` to `build/web`, so the built output (including `privacy/index.html` and `delete-account/index.html`) is deployed as-is.

**Cache headers:** Firebase Hosting matches `headers[].source` against the **original request path before rewrites** (first match wins). Default HTML cache is `max-age=3600`, so `/index.html` rules alone miss `/` and SPA deep links. The checked-in [`firebase.json`](../firebase.json) sets `must-revalidate` on entry scripts / manifest / messaging SW / invite HTML, then a catch-all `**` `must-revalidate` for `/` and all SPA routes (including `/invite/**`), while allowing long cache for static images/fonts. Deploy is via GitHub Actions (`deploy-web` on `v*` tags), not a local `firebase deploy`.

### 3. Keeping secrets out of your shell history

- **Option A – CI (recommended)**  
  Use GitHub Actions (or similar) and store `SUPABASE_URL` and `SUPABASE_ANON_KEY` as **repository secrets**. In the workflow, run the same `flutter build web --dart-define=...` using `${{ secrets.SUPABASE_URL }}` (and the anon key), then deploy via `FirebaseExtended/action-hosting-deploy` using `FIREBASE_SERVICE_ACCOUNT`. The build and deploy happen in CI; you never type secrets locally.

- **Option B – Local script**  
  Put the build command in a script that reads from env vars (e.g. `SUPABASE_URL`, `SUPABASE_ANON_KEY`) and passes them to `--dart-define`. Source the vars from a file that is gitignored (e.g. `.env.production`) so you don't commit them. Never commit that file or the script's contents with real keys.

- **Option C – One-off**  
  Run the `flutter build web --dart-define=...` command once locally and then deploy. Keys will be in your shell history unless your shell is configured not to persist it.

After the first deploy, confirm the live URL (`https://hisab.shenepoy.com` or `https://hisab-c8eb1.web.app`) is in Supabase redirect URLs if you didn't use `SITE_URL` in the initial build.

---

## Troubleshooting

### App works offline but nothing syncs

- Verify both `--dart-define` parameters are set correctly.
- Check Supabase project status in the dashboard.

### OAuth redirect issues

- **Mobile**: Ensure the app scheme (`io.supabase.hisab`) is registered in Android/iOS config.
- **Web**: Verify the redirect URL is in Supabase Authentication → URL Configuration → Redirect URLs. Prefer HTTPS `SITE_URL` matching the live origin.
- After return, if the stock Supabase URI recovery leaves no session, the app retries once and may toast `auth_oauth_callback_failed` / `auth_oauth_timeout`, then clears `?code=` / fragment auth params so a refresh cannot reuse a spent code.
- Add `http://localhost:*` (or your fixed port, e.g. `http://localhost:8080`) to Supabase redirect URLs for local development.

### "RLS policy violation" errors

- Ensure the user is authenticated.
- Verify the user has the correct role for the operation.
- For new group creation, `owner_id` must match `auth.uid()`.

### Migration fails when switching to online

- Ensure you have a stable internet connection.
- Try again — the migration is idempotent (uses upserts).
