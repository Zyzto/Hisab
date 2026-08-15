#!/usr/bin/env bash
# Materialize an Android signing keystore from base64 and point Gradle at it.
#
# Reads KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS and KEY_PASSWORD. With
# none of them set this exits 0 without writing anything, which is what a
# contributor building locally wants: android/app/build.gradle.kts falls back
# to debug signing when android/key.properties is absent.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${KEYSTORE_BASE64:-}" ]]; then
  echo "KEYSTORE_BASE64 not set — building with debug signing"
  exit 0
fi

: "${KEYSTORE_PASSWORD:?KEYSTORE_PASSWORD required when KEYSTORE_BASE64 is set}"
: "${KEY_ALIAS:?KEY_ALIAS required when KEYSTORE_BASE64 is set}"
KEY_PASSWORD="${KEY_PASSWORD:-$KEYSTORE_PASSWORD}"

keystore_path="$ROOT_DIR/android/app/release-keystore.jks"
echo "$KEYSTORE_BASE64" | base64 --decode > "$keystore_path"

printf 'storeFile=%s\nstorePassword=%s\nkeyAlias=%s\nkeyPassword=%s\n' \
  "$keystore_path" "$KEYSTORE_PASSWORD" "$KEY_ALIAS" "$KEY_PASSWORD" \
  > android/key.properties

echo "Wrote android/key.properties for alias $KEY_ALIAS"
