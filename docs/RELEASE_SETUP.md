# Release Setup Guide

This document covers every manual step needed **outside the codebase** to make the CI/CD pipeline work. The pipeline lives in `.github/workflows/release.yml` and does three things:

1. Builds a signed Android APK and AAB, attaches the APK to a GitHub Release.
2. Uploads the AAB to Google Play (internal testing track).
3. Builds the Flutter web app and deploys it to Firebase Hosting.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Generate an Android Release Keystore](#2-generate-an-android-release-keystore)
3. [Base64-Encode the Keystore](#3-base64-encode-the-keystore)
4. [Set Up Google Play](#4-set-up-google-play)
5. [Create a Google Play Service Account](#5-create-a-google-play-service-account)
6. [Set Up Firebase Hosting](#6-set-up-firebase-hosting)
7. [Add All Secrets to GitHub](#7-add-all-secrets-to-github)
8. [First Release Checklist](#8-first-release-checklist)
9. [Local Development Notes](#9-local-development-notes)

---

## 1. Prerequisites

- A GitHub repository with this codebase pushed.
- A [Google Play Developer account](https://play.google.com/console/) ($25 one-time fee).
- A [Firebase project](https://console.firebase.google.com/) (the free Spark plan is enough for Hosting).
- `keytool` (ships with Java / JDK).

---

## 2. Generate an Android Release Keystore

Run this once on your local machine. **Keep the generated `.jks` file safe** — you will need it for every future release and to push updates to Google Play.

```bash
keytool -genkeypair \
  -v \
  -keystore release-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias hisab-release \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD
```

When prompted, fill in your name / organisation details (they are baked into the certificate but are not shown publicly on Google Play).

| Value | What to remember |
|-------|-----------------|
| File  | `release-keystore.jks` |
| Alias | `hisab-release` (or whatever you chose with `-alias`) |
| Store password | The `-storepass` value |
| Key password   | The `-keypass` value |

> **Never commit the keystore or passwords to git.** The `android/.gitignore` already excludes `*.jks` and `key.properties`.

---

## 3. Base64-Encode the Keystore

GitHub Secrets can only hold text, so we encode the binary keystore as base64.

```bash
base64 -i release-keystore.jks | tr -d '\n'
```

Copy the entire output — that is the value for the `KEYSTORE_BASE64` secret.

On Linux the flag is `-w 0` instead of `-i`:

```bash
base64 -w 0 release-keystore.jks
```

---

## 4. Set Up Google Play

Before the workflow can upload builds, you need to create the app listing manually (Google Play requires the first APK/AAB to be uploaded by hand).

### 4a. Create the app on Google Play Console

1. Go to [Google Play Console](https://play.google.com/console/).
2. **Create app** -> fill in the app name ("Hisab"), default language, app type (App), free/paid.
3. Complete the **Store listing** (description, screenshots, icon, etc.) — only the required fields need to be filled.
4. Complete the **Content rating** questionnaire.
5. Complete the **Target audience and content** section.

### 4b. Upload the first build manually

1. Build a signed AAB locally:
   ```bash
   # First create android/key.properties pointing to your keystore:
   cat > android/key.properties <<EOF
   storeFile=/absolute/path/to/release-keystore.jks
   storePassword=YOUR_STORE_PASSWORD
   keyAlias=hisab-release
   keyPassword=YOUR_KEY_PASSWORD
   EOF

   flutter build appbundle --release \
     --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
   ```
2. In Google Play Console, go to **Release > Testing > Internal testing**.
3. Click **Create new release**, upload `build/app/outputs/bundle/release/app-release.aab`.
4. Fill in release notes and **Save & review** -> **Start rollout to Internal testing**.

After this first manual upload, the CI workflow can push subsequent builds automatically via the API.

---

## 5. Create a Google Play Service Account

The workflow uses a GCP service account to authenticate with the Google Play Developer API.

### 5a. Create the service account in Google Cloud

1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Select (or create) a GCP project linked to your Play Console.
3. Navigate to **IAM & Admin > Service Accounts**.
4. Click **Create Service Account**.
   - Name: `github-play-deploy` (or anything descriptive).
   - Role: no role needed here (permissions are granted in Play Console).
5. Click **Done**, then click the new service account row.
6. Go to the **Keys** tab -> **Add Key** -> **Create new key** -> **JSON**.
7. Download the JSON file. Its contents are the value for the `PLAY_STORE_SERVICE_ACCOUNT_JSON` secret.

### 5b. Grant access in Google Play Console

1. In [Google Play Console](https://play.google.com/console/), go to **Users and permissions**.
2. Click **Invite new users**.
3. Enter the service account email (from step 5a, looks like `github-play-deploy@project.iam.gserviceaccount.com`).
4. Under **App permissions**, select **Hisab** and grant:
   - **Release to production, exclude devices, and use Play App Signing** (or at minimum **Manage testing tracks and edit tester lists**).
5. Click **Invite user** -> **Send invitation**.
6. Accept the invitation (it may auto-accept for service accounts).

> It can take up to 24 hours for the permissions to propagate. If the first workflow run fails with a 403, wait and retry.

---

## 6. Set Up Firebase Hosting

### 6a. Create / confirm your Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/).
2. You should already have project **hisab-c8eb1** (per `.firebaserc`). If not, create one.
3. Navigate to **Build > Hosting** and click **Get started** if Hosting is not yet enabled.

### 6b. Generate a Firebase service account for CI

The workflow uses a GCP service account JSON to deploy. The simplest way:

1. Go to **Firebase Console > Project settings > Service accounts**.
2. Click **Generate new private key**. Download the JSON file.
3. The entire contents of that JSON file is the value for the `FIREBASE_SERVICE_ACCOUNT` secret.

Alternatively, if you prefer a scoped service account:

1. Go to [Google Cloud Console > IAM & Admin > Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts).
2. Select the Firebase project.
3. Create a service account with the roles:
   - **Firebase Hosting Admin** (`roles/firebasehosting.admin`)
   - **Service Account User** (`roles/iam.serviceAccountUser`)
4. Create a JSON key and use its contents as the secret.

### 6c. Note your Hosting URL

After the first deploy, your site will be live at:

```
https://hisab-c8eb1.web.app
```

(or a custom domain if you configure one). Use this URL as the `SITE_URL` secret so auth redirects land on the live site. Also add it to **Supabase Dashboard > Authentication > URL Configuration > Redirect URLs**.

---

## 7. Add All Secrets to GitHub

Go to your GitHub repository -> **Settings** -> **Secrets and variables** -> **Actions** -> **New repository secret**.

Add each secret listed below:

| Secret name | Value |
|-------------|-------|
| `SUPABASE_URL` | Your Supabase project URL, e.g. `https://xxxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Your Supabase anon/public key (starts with `eyJ...`) |
| `SITE_URL` | Your Firebase Hosting URL, e.g. `https://hisab-c8eb1.web.app` |
| `KEYSTORE_BASE64` | The base64-encoded keystore from [step 3](#3-base64-encode-the-keystore) |
| `KEYSTORE_PASSWORD` | The store password you chose in [step 2](#2-generate-an-android-release-keystore) |
| `KEY_ALIAS` | The key alias, e.g. `hisab-release` |
| `KEY_PASSWORD` | The key password from [step 2](#2-generate-an-android-release-keystore) |
| `PLAY_STORE_SERVICE_ACCOUNT_JSON` | The full JSON contents from [step 5a](#5a-create-the-service-account-in-google-cloud) |
| `FIREBASE_SERVICE_ACCOUNT` | The full JSON contents from [step 6b](#6b-generate-a-firebase-service-account-for-ci) |
| `GOOGLE_SERVICES_JSON` | Base64-encoded contents of `android/app/google-services.json` (Firebase Console → Project settings → your Android app → download `google-services.json`, then `base64 -w 0 android/app/google-services.json` or equivalent) |
| `FCM_VAPID_KEY` | Web Push certificate VAPID key from Firebase Console → Project Settings → Cloud Messaging → Web Push certificates (needed for web and optionally for Android FCM) |

---

## 8. First Release Checklist

Once all secrets are in place:

### Option A: Tag push (recommended for real releases)

1. Update the version in `pubspec.yaml`:
   ```yaml
   version: 1.0.0+1
   ```
   The format is `MARKETING_VERSION+BUILD_NUMBER`. Increment the build number for every Play Store upload (Google rejects duplicate version codes).

2. Commit and push:
   ```bash
   git add pubspec.yaml
   git commit -m "Bump version to 1.0.0+1"
   git push
   ```

3. Tag and push the tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

4. The workflow triggers automatically. Monitor progress in the repository **Actions** tab.

### Option B: Manual dispatch (for testing the pipeline)

1. Go to your repository -> **Actions** -> **Release** workflow.
2. Click **Run workflow**.
3. Choose which deployments to enable (Play Store, Firebase).
4. Click **Run workflow**.

### What happens

- **build-android**: Builds a signed APK and AAB, uploads them as artifacts.
- **github-release** (tag pushes only): Creates a GitHub Release with the APK attached.
- **deploy-play-store**: Uploads the AAB to the Google Play internal testing track.
- **deploy-web**: Builds the Flutter web app and deploys to Firebase Hosting.

---

## 9. Local Development Notes

### pubspec_overrides.yaml

The main `pubspec.yaml` may use `git:` dependencies for some packages (so CI can resolve them). For local development, you can add a `pubspec_overrides.yaml` to redirect those dependencies to local paths (e.g. sibling packages you are developing).

This file is automatically gitignored by `dart pub`. If you use it and delete it by accident, recreate it with your local paths:

```yaml
dependency_overrides:
  some_package:
    path: ../your-local-package
```

Replace `some_package` and `../your-local-package` with the actual package name and path.

### Local signing (optional)

If you want to test release builds locally, create `android/key.properties`:

```properties
storeFile=/absolute/path/to/release-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=hisab-release
keyPassword=YOUR_KEY_PASSWORD
```

This file is gitignored. Without it, release builds fall back to debug signing.

### Flutter version

The workflow pins Flutter to a specific version via `FLUTTER_VERSION` in `.github/workflows/release.yml`. When you upgrade locally, update that env var to match so CI and local builds stay in sync.
