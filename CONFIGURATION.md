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

This creates a Convex project (if needed) and pushes the schema and functions from `convex/`.

### 1.3 Set deployment URL

In `lib/core/constants/app_secrets.dart`:

```dart
const String convexDeploymentUrl = 'https://your-deployment.convex.cloud';
```

Use the URL shown in the Convex dashboard or after `npx convex dev`.

### 1.4 Auth (for Convex)

Convex uses Auth0 for JWT verification. Set these environment variables when running Convex:

```bash
export AUTH0_DOMAIN="your-tenant.us.auth0.com"
export AUTH0_CLIENT_ID="your-client-id"
npx convex dev
```

Those values are read by `convex/auth.config.ts`. They must match Auth0 config.

### 1.5 Telemetry (optional)

The app can send anonymous usage events to a Convex HTTP action. In `app_secrets.dart`:

```dart
const String telemetryEndpointUrl = 'https://your-deployment.convex.site/telemetry';
```

Use your Convex deployment's `.convex.site` URL (not `.convex.cloud`). Find it in Dashboard → Settings → URL. The `/telemetry` route is defined in `convex/http.ts` and stores events in the `telemetry` table.

Leave empty to disable telemetry.

---

## 2. Auth0

### 2.1 Create application

1. Go to [Auth0 Dashboard](https://manage.auth0.com/#/applications/) → Create Application.
2. Choose **Native**.
3. Under **Application URIs** set:
   - **Allowed Callback URLs** and **Allowed Logout URLs**:

   | Platform | URL |
   |----------|-----|
   | Android | `https://YOUR_DOMAIN/android/com.example.hisab/callback` |
   | iOS | `https://YOUR_DOMAIN/ios/com.example.hisab/callback,com.example.hisab://YOUR_DOMAIN/ios/com.example.hisab/callback` |
   | Web | `http://localhost:3000` (or your web origin) |
   | macOS | `https://YOUR_DOMAIN/macos/com.example.hisab/callback,...` |

   Replace `YOUR_DOMAIN` with your Auth0 domain (e.g. `tenant.us.auth0.com`). Replace `com.example.hisab` with your app’s package/bundle ID if different.

4. Note the **Client ID** and **Domain** from the Auth0 Dashboard.

### 2.2 Flutter config

In `lib/core/constants/app_secrets.dart`:

```dart
const String auth0Domain = 'your-tenant.us.auth0.com';
const String auth0ClientId = 'your-client-id';
```

### 2.3 Android

In `android/secrets.properties` (copy from `secrets.properties.example`):

```properties
auth0Domain=your-tenant.us.auth0.com
auth0Scheme=https
```

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
      <string>com.example.hisab</string>
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
| Convex URL | `app_secrets.dart` → `convexDeploymentUrl` |
| Telemetry URL | `app_secrets.dart` → `telemetryEndpointUrl` = `https://<deployment>.convex.site/telemetry` (optional) |
| Convex auth env | `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID` when running `npx convex dev` |
| Auth0 domain & client | `app_secrets.dart` → `auth0Domain`, `auth0ClientId` |
| Android placeholders | `android/secrets.properties` → `auth0Domain`, `auth0Scheme` |
| iOS URL scheme | `ios/Runner/Info.plist` (if using Auth0 on iOS) |
| Auth0 Dashboard | Callback URLs for Android, iOS, Web |

---

## 4. Local Only

If `auth0Domain` and `auth0ClientId` are empty in `app_secrets.dart`, the app runs in Local Only mode. Convex is not initialized and the app uses only local storage (Drift). No Auth0 or Convex setup is required.
