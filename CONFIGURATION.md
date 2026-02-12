# Configuring Convex and Auth0

This app supports **online sync** (Convex + Auth0) and **local-only** mode. When both are configured, users can sign in with Auth0 and sync data to Convex. Otherwise, the app runs in Local Only mode.

Secrets are kept out of git via gitignored files. Templates are committed.

---

## 0. First-time setup

Copy the example files and fill in your values (or leave empty for Local Only):

```bash
cp lib/core/constants/app_secrets_example.dart lib/core/constants/app_secrets.dart
cp android/secrets.properties.example android/secrets.properties
```

- `app_secrets.dart` — Auth0, Convex URL, report issue URL, telemetry (gitignored)
- `android/secrets.properties` — Auth0 manifest placeholders for Android (gitignored)

---

## 1. Convex

### 1.1 Install

```bash
npm install -g convex
```

Or use `npx convex` without global install.

### 1.2 Create project

```bash
cd hisab
npx convex dev
```

**Important:** Run from the directory containing `package.json` and `convex/`.

This creates a Convex project (if needed) and pushes the schema and functions from `convex/`. If you see "Could not resolve convex/server" or temp-dir warnings, ensure `convex` is in `dependencies` (not just devDependencies), run `npm install`, and add `CONVEX_TMPDIR=./convex/.tmp` to the command (or to `package.json` scripts such as `"convex:dev": "CONVEX_TMPDIR=./convex/.tmp convex dev"`).

### 1.3 Set deployment URLs

In `lib/core/constants/app_secrets.dart`:

```dart
// Dev (debug builds)
const String convexDeploymentUrlDev = 'https://your-dev-deployment.convex.cloud';

// Prod (release builds)
const String convexDeploymentUrlProd = 'https://your-prod-deployment.convex.cloud';
```

- **Debug** builds use `convexDeploymentUrlDev` (from `npx convex dev`).
- **Release** builds use `convexDeploymentUrlProd` (from `npx convex deploy`).

Use the URLs shown in the Convex dashboard or after running the commands.

### 1.4 Auth (for Convex)

Convex uses Auth0 for JWT verification. **Set these in the Convex Dashboard** (recommended) so they persist:

1. Go to [Convex Dashboard](https://dashboard.convex.dev) → your project → **Dev** deployment → Settings → Environment variables.
2. Add `AUTH0_DOMAIN` and `AUTH0_CLIENT_ID` (same values as in `app_secrets.dart` for that deployment — dev or prod).
3. Run `npx convex dev` — the push will succeed only if these are set.

Alternatively, set them when running:
```bash
export AUTH0_DOMAIN="your-tenant.us.auth0.com"
export AUTH0_CLIENT_ID="your-client-id"
npx convex dev
```

Those values are read by `convex/auth.config.ts`. They must match Auth0 config. **Each deployment (dev, prod) has its own env vars** — set them for prod too if you deploy.

### 1.5 Telemetry (optional)

The app can send anonymous usage events to a Convex HTTP action. In `app_secrets.dart`:

```dart
const String telemetryEndpointUrlDev = 'https://your-dev-deployment.convex.site/telemetry';
const String telemetryEndpointUrlProd = 'https://your-prod-deployment.convex.site/telemetry';
```

Use each deployment's `.convex.site` URL (not `.convex.cloud`). Find it in Dashboard → Settings → URL. The `/telemetry` route is defined in `convex/http.ts`. Debug builds use Dev; release uses Prod. Leave empty to disable telemetry.

---

## 2. Auth0

### 2.1 Create application

1. Go to [Auth0 Dashboard](https://manage.auth0.com/#/applications/) → Create Application.
2. Choose **Native**.
3. Under **Application URIs** set:
   - **Allowed Callback URLs** and **Allowed Logout URLs**:

   | Platform | URL |
   |----------|-----|
   | Android (HTTPS) | `https://YOUR_DOMAIN/android/com.shenepoy.hisab/callback` |
   | Android (custom scheme) | `com.shenepoy.hisab://YOUR_DOMAIN/android/com.shenepoy.hisab/callback` |
   | iOS | `https://YOUR_DOMAIN/ios/com.shenepoy.hisab/callback,com.shenepoy.hisab://YOUR_DOMAIN/ios/com.shenepoy.hisab/callback` |
   | Web | `http://localhost:3000` (or your web origin) |

   Replace `YOUR_DOMAIN` with your Auth0 domain (e.g. `tenant.us.auth0.com`). Replace `com.shenepoy.hisab` with your app’s package/bundle ID if different.

4. Note the **Client ID** and **Domain** from the Auth0 Dashboard.

### 2.2 Flutter config

In `lib/core/constants/app_secrets.dart`:

```dart
// Dev (debug builds)
const String auth0DomainDev = 'your-dev-tenant.us.auth0.com';
const String auth0ClientIdDev = 'your-dev-client-id';

// Prod (release builds)
const String auth0DomainProd = 'your-prod-tenant.us.auth0.com';
const String auth0ClientIdProd = 'your-prod-client-id';
```

Debug builds use dev; release builds use prod. You can use the same Auth0 tenant for both if desired.

### 2.3 Android

In `android/secrets.properties` (copy from `secrets.properties.example`):

```properties
auth0DomainDev=your-dev-tenant.us.auth0.com
auth0DomainProd=your-prod-tenant.us.auth0.com
auth0Scheme=com.shenepoy.hisab
```

- `auth0DomainDev` — Auth0 tenant for **debug** builds (e.g. `dev-xxx.eu.auth0.com`).
- `auth0DomainProd` — Auth0 tenant for **release** builds.
- `auth0Scheme` — Use your package ID as a custom scheme (e.g. `com.shenepoy.hisab`) for more reliable redirects on Android. Optionally `https` for universal links.

**Important:** `auth0Scheme` in `app_secrets.dart` must match. Add the callback URL to Auth0 Dashboard (see §2.1); for custom scheme it is `com.shenepoy.hisab://YOUR_DOMAIN/android/com.shenepoy.hisab/callback`. Add URLs for both dev and prod domains if they differ.

These are read by `build.gradle.kts` for the auth0_flutter manifest. Falls back to `example.com` / `https` if the file is missing.

### 2.4 iOS

If using Auth0 on iOS, add the URL scheme in `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.shenepoy.hisab</string>
    </array>
    <key>CFBundleURLName</key>
    <string>auth0</string>
  </dict>
</array>
```

Use your bundle ID if different. See [Auth0 Flutter docs](https://auth0.com/docs/quickstart/native/flutter/interactive) for details.

### 2.5 Web

- Allowed Callback URLs: `http://localhost:3000` (or your web URL)
- Allowed Logout URLs: same
- Allowed Web Origins: same

Run web with: `flutter run -d chrome --web-port 3000`.

---

## 3. Quick checklist

| Step | File / action |
|------|---------------|
| First-time | Copy `app_secrets_example.dart` → `app_secrets.dart`, `secrets.properties.example` → `secrets.properties` |
| Convex URLs | `app_secrets.dart` → `convexDeploymentUrlDev`, `convexDeploymentUrlProd` (dev from `npx convex dev`, prod from `npx convex deploy`) |
| Telemetry URLs | `app_secrets.dart` → `telemetryEndpointUrlDev`, `telemetryEndpointUrlProd` (optional) |
| Convex auth env | **Convex Dashboard** → Dev **and** Prod deployments → Settings → Environment variables: `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID` for each |
| Convex push | `npm install` then `npx convex dev` from project root |
| Auth0 domain & client | `app_secrets.dart` → `auth0DomainDev`, `auth0ClientIdDev`, `auth0DomainProd`, `auth0ClientIdProd` |
| Android placeholders | `android/secrets.properties` → `auth0DomainDev`, `auth0DomainProd`, `auth0Scheme` (use package ID for custom scheme) |
| iOS URL scheme | `ios/Runner/Info.plist` (if using Auth0 on iOS) |
| Auth0 Dashboard | Callback URLs for Android (custom scheme or HTTPS), iOS, Web — add both dev and prod domains if different |

---

## 4. Local Only

If `auth0DomainDev` and `auth0ClientIdDev` (and prod equivalents) are empty in `app_secrets.dart`, the app runs in Local Only mode. Convex is not initialized and the app uses only local storage (Drift). No Auth0 or Convex setup is required.

---

## 5. Build modes (debug vs release)

| Build | Convex | Auth0 |
|-------|--------|-------|
| **Debug** (`flutter run`, `flutter run --debug`) | Dev deployment (`convexDeploymentUrlDev`) | Dev tenant (`auth0DomainDev`, `auth0ClientIdDev`) |
| **Release** (`flutter run --release`, `flutter build`) | Prod deployment (`convexDeploymentUrlProd`) | Prod tenant (`auth0DomainProd`, `auth0ClientIdProd`) |

Android `manifestPlaceholders` are set per build type in `build.gradle.kts` from `secrets.properties` (`auth0DomainDev` / `auth0DomainProd`).

---

## 6. Troubleshooting

### Auth0

#### "Callback URL mismatch"

Auth0 shows this when the redirect URL is not in the allowed list. Add the exact URL to Dashboard → Applications → your app → Settings → **Allowed Callback URLs** and **Allowed Logout URLs**:

| Platform | URL |
|----------|-----|
| Android (HTTPS) | `https://YOUR_DOMAIN/android/YOUR_PACKAGE_ID/callback` |
| Android (custom scheme) | `YOUR_SCHEME://YOUR_DOMAIN/android/YOUR_PACKAGE_ID/callback` |
| Web | `http://localhost:3000` (or your origin) |

Use your Auth0 domain and package ID from `applicationId` in `android/app/build.gradle.kts`. Click **Save Changes** after adding.

#### Android: Auth0 "not found" after sign-in

If Auth0 redirects but the app shows "not found" or fails to complete login on Android, switch to a **custom scheme** instead of HTTPS:

1. In `android/secrets.properties`: set `auth0Scheme=com.shenepoy.hisab` (or your package ID). Dev and prod domains come from `auth0DomainDev` and `auth0DomainProd`.
2. In `app_secrets.dart`: set `auth0Scheme = 'com.shenepoy.hisab'` (same value). Auth0 domain/client are per build mode (§5).
3. In Auth0 Dashboard → Allowed Callback URLs, add:
   `com.shenepoy.hisab://YOUR_DOMAIN/android/com.shenepoy.hisab/callback`
4. In Auth0 Dashboard → Allowed Logout URLs, add the same or your app's return URL.

#### Convex auth: use ID token, not access token

Convex validates Auth0 **ID tokens** (not access tokens). The app's `auth0GetAccessToken()` returns `credentials.idToken ?? credentials.accessToken` so Convex receives the correct token. If mutations or queries hang or timeout, verify the auth token is the ID token.

---

### Convex

#### "Could not resolve convex/server"

This occurs when bundling Convex component definitions. Fixes:

1. **Ensure `convex` is a dependency** (not just devDependency) in `package.json`:
   ```json
   "dependencies": { "convex": "^1.19.0" }
   ```

2. **Install dependencies**: run `npm install` from the project root (where `package.json` lives).

3. **`CONVEX_TMPDIR` on different filesystem**: If `/tmp` and `convex/_generated` are on different filesystems, set:
   ```bash
   export CONVEX_TMPDIR=./convex/.tmp
   ```
   Or add to `package.json` scripts:
   ```json
   "convex:dev": "CONVEX_TMPDIR=./convex/.tmp convex dev"
   ```
   Add `convex/.tmp/` to `.gitignore`.

4. **Run from project root**: `npx convex dev` must run from the directory containing `package.json` and `convex/`.

#### "Could not find public function for 'groups:list'"

The Convex backend has no functions deployed. Do this:

1. **Set env vars in Convex Dashboard** for your **dev** deployment:
   - [Dashboard → Dev deployment → Settings → Environment variables](https://dashboard.convex.dev)
   - Add `AUTH0_DOMAIN` and `AUTH0_CLIENT_ID` (same values as in `app_secrets.dart`).

2. **Push functions**:
   ```bash
   cd hisab
   npx convex dev
   ```
   Keep it running or run once until "Convex functions ready!" appears.

3. **Use the correct deployment**: The app uses `convexDeploymentUrl` from `app_secrets.dart`. For dev, this should be the **dev** deployment URL (e.g. `https://coordinated-spoonbill-223.eu-west-1.convex.cloud`). `npx convex deploy` pushes to **prod**; if the app points to dev, deploy to dev with `npx convex dev`.

#### "Environment variable AUTH0_DOMAIN is used in auth config but its value was not set"

Set `AUTH0_DOMAIN` and `AUTH0_CLIENT_ID` in the Convex Dashboard for the deployment you're pushing to (dev or prod). Each deployment has its own env vars.

- **Dev**: Dashboard → select Dev deployment → Settings → Environment variables.
- **Prod**: Dashboard → select Prod deployment → Settings → Environment variables.

#### "ArgumentValidationError: Value does not match validator" — IDs

If the error shows an ID value like `"\"jn77a48yv8hmsy42kka2ayaws9811qhw\""` (double-encoded), the Convex repository uses `_normalizeConvexId()` to strip JSON string encoding before passing IDs to Convex. This is already handled in `convex_repository.dart`.

#### "ArgumentValidationError" — numbers (order, amountCents, date, etc.)

**convex_flutter** converts all mutation args to strings with `v.toString()`. So `order: 0` becomes `"0"`, and Convex's `v.number()` validator rejects it.

The Convex functions in this project use `v.union(v.string(), v.number())` for numeric args and `parseFloat()` in the handler. This is already implemented in `participants.ts`, `expenses.ts`, `groups.ts`, and `expense_tags.ts`.

#### Mutation timeout (30 seconds)

Possible causes:

1. **Wrong auth token** — Convex expects the Auth0 ID token. The app uses `idToken ?? accessToken`. If still failing, sign out and sign back in to refresh tokens.
2. **Unstable connection** — WebSocket reconnecting repeatedly; check network, emulator connectivity, or try a real device.
3. **Functions not deployed** — Ensure `npx convex dev` has run and env vars are set so the push succeeds.

---

### convex_flutter implementation note

The `convex_flutter` package converts all mutation/action args to strings (`v.toString()`) before sending to Convex. Numbers like `order: 0` become `"0"`. This project's Convex validators accept `v.union(v.string(), v.number())` for numeric fields and parse them in the handler. If you add new numeric args to Convex mutations called from Flutter, use the same pattern (see `participants.ts`, `expenses.ts`, etc.).

---

### Quick reference

| Issue | Fix |
|-------|-----|
| Callback URL mismatch | Add exact URL to Auth0 Dashboard |
| Auth0 "not found" on Android | Use custom scheme in `auth0Scheme` |
| convex/server resolve error | `convex` in dependencies, `npm install`, `CONVEX_TMPDIR` |
| Functions not found | Set AUTH0_DOMAIN/AUTH0_CLIENT_ID in Convex Dashboard, run `npx convex dev` |
| AUTH0_DOMAIN not set (deploy) | Set env vars in Convex Dashboard for that deployment |
| ID validation error | `_normalizeConvexId` in repository (already applied) |
| Number validation error | Convex validators accept string \| number (already applied) |
| Mutation timeout | Check auth (ID token), connection, deployment |
