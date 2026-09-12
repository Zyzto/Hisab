# Release setup

This repository releases the public local-only application for Android, iOS,
and web. It has no runtime service credentials.

The public release uses the `foss` flavor.

## Prerequisites

- Flutter version from .flutter-version;
- JDK and Android SDK for Android builds;
- an Apple signing environment for iOS;
- a signing keystore for distributable Android builds.

## Android signing

Generate a keystore once and keep it outside the repository:

    keytool -genkeypair -keystore foss-keystore.jks -alias hisab-foss -keyalg RSA -keysize 2048

Create a gitignored android/key.properties for local signing. CI accepts
FOSS_KEYSTORE_BASE64, FOSS_KEYSTORE_PASSWORD, FOSS_KEY_ALIAS, and
FOSS_KEY_PASSWORD. Never commit any of these values.

Build the only public Android flavor:

    bash scripts/ci/build_android.sh release

## Web

    bash scripts/ci/build_web.sh

The script prepares local database assets, builds Flutter web, and stages the
privacy, data-deletion, feature, image, and PWA files.

## Store listing legal links

Use these public URLs in the Google Play and Apple App Store listings:

- Privacy policy: `https://hisab.shenepoy.com/privacy/`
- Data deletion: `https://hisab.shenepoy.com/delete-account/`

The deletion page explains that this local-only app creates no account and
gives the exact steps for removing local records, backups, and app storage.

## iOS

Validate the unsigned local build on macOS with Xcode installed:

    bash scripts/ci/build_ios.sh

The CI guard performs this build without signing credentials. App Store
signing and upload remain release-operator steps in Xcode or App Store
Connect.

## Pre-release checks

    bash scripts/run_release_checks.sh
    flutter test

The release workflow builds the FOSS APKs and creates a draft release. Publish
only after checking the generated artifacts and localized static pages.

Before publishing, confirm that the artifact set contains only the local
application and that `bash scripts/ci/assert_offline_only.sh` passes.

## Versioning

Update pubspec.yaml with an increasing marketing.build version such as
1.0.0+1, then tag the release according to the repository policy.

## Data safety

Test database upgrades, backup restore, receipt attachment, local OCR, and
scanner drafts before publishing. Do not add a migration that drops legacy
tables or columns without an explicit user-data export path.
