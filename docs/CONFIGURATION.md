# Configuration

<!-- markdownlint-disable MD031 MD032 MD034 MD060 -->

Hisab is **offline-first**: SQLite (PowerSync package) always runs on device.
A backend is optional and, in this repository, absent — `packages/hisab_cloud`
is a no-op stub, so a plain `flutter run` gives you the full local-only app with
nothing to configure.

Everything below is therefore in two parts: flags the **client** reads, and
flags a **backend package** may read. All of them arrive at build time via
`--dart-define`. Nothing sensitive belongs in the repo — see
[SECURITY.md](../SECURITY.md).

- Attaching your own backend → [SELF_HOSTING.md](SELF_HOSTING.md)
- What the server must do → [BACKEND_BEHAVIOUR.md](BACKEND_BEHAVIOUR.md)

---

## Quick start

### Local-only (default)

```bash
flutter run                 # web, desktop
flutter run --flavor foss   # Android
```

No defines, no keys, no network. Authentication, sync, invites and telemetry
are disabled because there is no backend registered.

### With a backend

```bash
flutter run --flavor cloud --dart-define-from-file=dart_defines.json
```

The `cloud` Android flavor exists for backend-enabled builds: it carries the
deep-link intent filters and a distinct application id, so it installs
alongside a `foss` build instead of replacing it. Which defines belong in that
file is up to your backend package — see [Backend-supplied flags](#backend-supplied-flags).

---

## Client flags

These are read by code in this repository.

| Parameter | Scope | Description |
|-----------|-------|-------------|
| `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID` | Optional | Firebase web SDK options, used only for Cloud Messaging. No defaults are committed. On web they are also injected into `web/index.html` and `web/firebase-messaging-sw.js` at build time by `scripts/ci/inject_firebase_web_config.sh`. Omit them entirely and push is simply unavailable. |
| `FCM_VAPID_KEY` | Optional, web | VAPID key from Firebase Console → Web Push certificates. Required before the web build can register a push token. |
| `ENABLE_WEB_SEMANTICS` | Optional, web | Calls `SemanticsBinding.instance.ensureSemantics()` at startup. Defaults to `false`, because always-on semantics causes severe scroll and input jank on iOS Safari. Turn it on for accessibility-focused builds. |

Push notifications also need a server that sends them, so on a build with no
backend the Firebase flags do nothing useful.

### Receipt AI (optional, no build flags)

Configured at runtime under **Settings → Receipt / AI** (hidden on web):

| Mode | Behavior | Platforms |
|---|---|---|
| **Off** | Attach photo only | Android, iOS |
| **On device (OCR)** | Tesseract4Android (Tess 5) / Apple Vision (iOS) + local heuristics (vendor/date/total); bundled `eng`+`ara` tessdata (~5.5MB raw ≈ ~2.7MB packaged) on Android via `ReceiptOcrBridge` | Android, iOS |
| **Gemini Nano** | On-device Gemini via AI Core; Check device / Download in settings | Android only (AI Core); iOS falls back to OCR |
| **Cloud** | BYO **Gemini** or **OpenAI** vision key | Android, iOS |

API keys here are **user-provided** and stored **only on the device**. They are
never sent to a Hisab backend and never committed. If cloud keys are missing or
Nano is unavailable, the app falls back to on-device OCR heuristics. Android
`minSdk` is **26** (required for ML Kit GenAI Prompt / Nano).

---

## Backend-supplied flags

A backend package defines its own configuration; the client neither reads nor
validates it. For reference, the hosted Hisab backend package uses:

| Parameter | Description |
|-----------|-------------|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Project URL and public key. Both must be present or the package registers no backend and the app stays local-only. |
| `INVITE_BASE_URL` | Origin used to build shareable invite links, so they carry your domain rather than the raw project URL. |
| `SITE_URL` | Redirect origin for auth emails and web OAuth. Must also be allow-listed server side. |

If you write your own package, use whatever names you like. The only contract
the app enforces is that `registerHisabCloud()` either installs a `CloudBackend`
or does not.

---

## App modes

### Local-only

- Everything works locally with zero restrictions.
- Groups, participants, expenses, settlement — all fully functional.
- No sign-in, no network calls.

### Online

- Requires a registered backend and a signed-in user.
- Writes go to the backend and are cached locally; reads always come from SQLite.
- If connectivity drops, expense writes queue and push on reconnect.
- Invites and member management need an active connection.

### Switching

- **Local → Online**: disabling "Local Only" in settings signs you in and migrates local data to the backend.
- **Online → Local**: enabling "Local Only" disconnects. Cached data stays available.

---

## Feature availability

| Feature | Local-Only | Online (connected) | Online (temporarily offline) |
|---------|------------|-------------------|------------------------------|
| Create/edit local data (groups, participants, expenses, tags) | Yes | Yes | Queued and pushed on reconnect |
| Record settlement | Yes | Yes | Queued for later push |
| Local data persistence | Yes | Yes | Yes |
| Authentication (email, OAuth) | No | Yes | N/A |
| Cloud sync across devices | No | Yes | Reconnects automatically |
| Group invites | No | Yes | Requires connectivity |
| Member management | No | Yes | Requires connectivity |
| Telemetry | No | Opt-in | No |
| Profile dashboard (local KPIs / budgets) | Yes | Yes | Yes (cached) |
| In-app notification history (`user_notifications`) | No | Yes (synced) | Cached after sync |
| Export/import backup | Yes | Yes | Yes |

### Connection status indicator

In online mode a status icon appears top-right: a green cloud when connected
and synced, a spinner while syncing, a red cloud-off when temporarily offline.
It is hidden entirely in local-only mode.

---

## IDE launch configuration

Committed [`.vscode/launch.json`](../.vscode/launch.json) defines the offline
launch configs. Add your own entries with `--dart-define-from-file=` pointing at
a gitignored define file if you run against a backend.

---

## Web notes

### Flutter default service worker deprecation

Flutter web is removing the default `flutter_service_worker.js` behavior. This
project uses a custom [`web/flutter_bootstrap.js`](../web/flutter_bootstrap.js)
that calls `_flutter.loader.load()` without default service-worker settings, so
web updates rely on normal browser/CDN caching. Firebase compat SDKs load
asynchronously in [`web/index.html`](../web/index.html); bootstrap waits on
`window.__hisabFirebaseReady` before starting Flutter. Context:
Flutter issue [#156910](https://github.com/flutter/flutter/issues/156910).

### iOS Safari performance and semantics

```bash
flutter build web --dart-define=ENABLE_WEB_SEMANTICS=true
```

Use this only for accessibility-targeted builds; it can reduce scroll
smoothness on iOS Safari. Visual and interaction cheap-paths are **per
surface** (iOS web vs Android web vs native), not blanket "all web". See
[`UiPerf`](../lib/core/platform/ui_perf.dart) and
[WEB_IOS_SAFARI_PERFORMANCE.md](WEB_IOS_SAFARI_PERFORMANCE.md).

### OPFS for better performance

```bash
flutter run -d chrome \
  --web-header "Cross-Origin-Opener-Policy=same-origin" \
  --web-header "Cross-Origin-Embedder-Policy=require-corp"
```

Without these headers the database falls back to IndexedDB — slower, but
compatible.

### Web SQLite

PowerSync on web needs `web/sqlite3.wasm` and `web/powersync_db.worker.js`. If
you see `Unexpected token '<'` for the worker or `Incorrect response MIME type`
for the WASM, run:

```bash
flutter pub run powersync:setup_web
```

This downloads the WASM and the single DB/sync worker into `web/` (and removes
any obsolete `powersync_sync.worker.js`). Rebuild so `build/web/` serves them.
`firebase.json` already serves `*.wasm` as `application/wasm`.

---

## Hosting the web build

Firebase Hosting — or any static host — serves **files only**. It provides no
runtime environment variables, so every flag above is baked into the JavaScript
at build time and is readable by anyone who opens devtools. Treat all of them as
public. Never ship a service-role or admin key to a client build; if your
backend has one, it belongs on the server.

```bash
bash scripts/ci/build_web.sh
bash scripts/ci/stage_web_static.sh
```

The second script copies the static `privacy` and `delete-account` pages into
`build/web/`, which Play Console requires to be reachable.

**Cache headers:** Firebase Hosting matches `headers[].source` against the
**original request path before rewrites**, first match wins. The default HTML
cache is `max-age=3600`, so an `/index.html` rule alone misses `/` and every SPA
deep link. The checked-in [`firebase.json`](../firebase.json) sets
`must-revalidate` on entry scripts, manifest, messaging service worker and the
invite HTML, then a catch-all `**` `must-revalidate` for `/` and all SPA routes,
while allowing long cache for static images and fonts.

---

## Troubleshooting

### Everything works but nothing syncs

Expected with no backend attached. Confirm your package's
`registerHisabCloud()` actually calls `registerCloudBackend(...)`, and that
whatever defines it requires were passed to the build.

### OAuth redirect issues

- **Mobile**: the app scheme `com.shenepoy.hisab` must be registered in the platform config, which for Android means building the `cloud` flavor. The legacy `io.supabase.hisab` scheme stays registered alongside it so links shared before the rename keep working.
- **Web**: the redirect origin must be allow-listed by your auth provider, and it should be HTTPS. A bare `http://` origin usually gets 301-redirected by the host, which breaks PKCE code exchange.
- After returning from the provider, if no session materializes the app retries once, may toast `auth_oauth_callback_failed` / `auth_oauth_timeout`, then clears `?code=` and fragment auth params so a refresh cannot reuse a spent code.

### Android build cannot find a flavor

Pass `--flavor foss` for offline builds or `--flavor cloud` when you have a
backend package. There is no default flavor.
