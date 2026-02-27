# GitHub Actions – Repository secrets

Add these in **GitHub → Your repo → Settings → Secrets and variables → Actions**. Create each name exactly as below.

---

## Required for Android build + release

| Secret | Description | Where to get it |
|--------|-------------|-----------------|
| `SUPABASE_URL` | Supabase project URL | Supabase Dashboard → Settings → API → Project URL (e.g. `https://xxxxx.supabase.co`) |
| `SUPABASE_ANON_KEY` | Supabase anon/public key | Supabase Dashboard → Settings → API → Project API keys → `anon` `public` |
| `FCM_VAPID_KEY` | Web push VAPID key (optional for Android; used if you build web too) | Firebase Console → Project Settings → Cloud Messaging → Web Push certificates → Key pair |
| `KEYSTORE_BASE64` | Android release keystore, base64-encoded | `base64 -w 0 android/app/release-keystore.jks | pbcopy` (or equivalent) |
| `KEYSTORE_PASSWORD` | Keystore password | The password you set when creating the keystore |
| `KEY_ALIAS_VAL` | Key alias in the keystore | e.g. `upload` |
| `KEY_PASSWORD_VAL` | Key password | The password for the key entry |
| `GOOGLE_SERVICES_JSON` | Firebase config for Android (base64) | Firebase Console → Project Settings → Your apps → Android app → Download `google-services.json`, then `base64 -w 0 google-services.json` |
| `PLAY_STORE_SERVICE_ACCOUNT_JSON` | Google Play API service account JSON (for uploading AAB) | Google Play Console → Setup → API access → Create service account, download JSON |

---

## Required for Web build + Firebase Hosting deploy

| Secret | Description | Where to get it |
|--------|-------------|-----------------|
| `SUPABASE_URL` | Same as above | Same as above |
| `SUPABASE_ANON_KEY` | Same as above | Same as above |
| `INVITE_BASE_URL` | Base URL for invite links (share/QR) | Your web app domain, e.g. `https://yourdomain.com` |
| `SITE_URL` | Production web app URL (auth redirects) | Same as your live domain, e.g. `https://yourdomain.com` |
| `FCM_VAPID_KEY` | Web push VAPID key for FCM on web | Firebase Console → Project Settings → Cloud Messaging → Web Push certificates |
| `FIREBASE_API_KEY` | Firebase web API key | Firebase Console → Project Settings → General → Your apps → Web app → API Key |
| `FIREBASE_AUTH_DOMAIN` | Firebase auth domain | e.g. `your-project-id.firebaseapp.com` |
| `FIREBASE_PROJECT_ID` | Firebase project ID | Firebase Console → Project Settings → General → Project ID |
| `FIREBASE_STORAGE_BUCKET` | Firebase storage bucket | e.g. `your-project-id.firebasestorage.app` |
| `FIREBASE_MESSAGING_SENDER_ID` | Firebase messaging sender ID | In your web app config in Firebase Console |
| `FIREBASE_APP_ID` | Firebase web app ID | e.g. `1:123456789:web:abcdef` |
| `FIREBASE_SERVICE_ACCOUNT` | Firebase Admin SDK service account JSON (for Hosting deploy) | Firebase Console → Project Settings → Service accounts → Generate new private key. Paste the **entire** JSON string as the secret value. |

`GITHUB_TOKEN` is provided automatically by Actions; you do not add it.

---

## Summary checklist

- [ ] `SUPABASE_URL`
- [ ] `SUPABASE_ANON_KEY`
- [ ] `INVITE_BASE_URL` (e.g. `https://yourdomain.com`)
- [ ] `SITE_URL` (e.g. `https://yourdomain.com`)
- [ ] `FCM_VAPID_KEY`
- [ ] `FIREBASE_API_KEY`
- [ ] `FIREBASE_AUTH_DOMAIN`
- [ ] `FIREBASE_PROJECT_ID`
- [ ] `FIREBASE_STORAGE_BUCKET`
- [ ] `FIREBASE_MESSAGING_SENDER_ID`
- [ ] `FIREBASE_APP_ID`
- [ ] `FIREBASE_SERVICE_ACCOUNT` (full JSON string)
- [ ] `KEYSTORE_BASE64`
- [ ] `KEYSTORE_PASSWORD`
- [ ] `KEY_ALIAS_VAL`
- [ ] `KEY_PASSWORD_VAL`
- [ ] `GOOGLE_SERVICES_JSON` (base64)
- [ ] `PLAY_STORE_SERVICE_ACCOUNT_JSON` (only if you deploy to Play)
