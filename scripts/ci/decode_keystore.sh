#!/usr/bin/env bash
# Materialize an Android signing keystore from base64 and point Gradle at it.
#
# Reads KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS and KEY_PASSWORD.
#
# The optional argument is the build mode. Debug builds may use Android's
# development key when no signing secret is present; release builds must fail
# closed rather than silently producing a debug-signed artifact.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

MODE="${1:-debug}"
if [[ "$MODE" != release && "$MODE" != debug ]]; then
  echo "usage: $0 [release|debug]" >&2
  exit 2
fi

if [[ -z "${KEYSTORE_BASE64:-}" ]]; then
  if [[ "$MODE" == release ]]; then
    echo "KEYSTORE_BASE64 is required for a release build" >&2
    exit 1
  fi
  echo "KEYSTORE_BASE64 not set — debug build will use Android's development key"
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
