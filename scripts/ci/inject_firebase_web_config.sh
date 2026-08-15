#!/usr/bin/env bash
# Replace the __FIREBASE_*__ placeholders in the built web output.
#
# The values are kept out of the tracked sources so a Firebase API key never
# lands in git; scripts/verify_security.sh fails the build if one does. With no
# FIREBASE_API_KEY set this exits 0 and the placeholders stay, which is correct
# for an offline build: it never calls Firebase.initializeApp.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${FIREBASE_API_KEY:-}" ]]; then
  echo "FIREBASE_API_KEY not set — leaving web Firebase placeholders in place"
  exit 0
fi

for f in build/web/index.html build/web/firebase-messaging-sw.js; do
  [[ -f "$f" ]] || continue
  sed -i \
    -e "s|__FIREBASE_API_KEY__|${FIREBASE_API_KEY}|g" \
    -e "s|__FIREBASE_AUTH_DOMAIN__|${FIREBASE_AUTH_DOMAIN:-}|g" \
    -e "s|__FIREBASE_PROJECT_ID__|${FIREBASE_PROJECT_ID:-}|g" \
    -e "s|__FIREBASE_STORAGE_BUCKET__|${FIREBASE_STORAGE_BUCKET:-}|g" \
    -e "s|__FIREBASE_MESSAGING_SENDER_ID__|${FIREBASE_MESSAGING_SENDER_ID:-}|g" \
    -e "s|__FIREBASE_APP_ID__|${FIREBASE_APP_ID:-}|g" \
    "$f"
done

echo "Injected Firebase web config"
