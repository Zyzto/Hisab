#!/usr/bin/env bash
# Print the --dart-define flags for the current environment, one per line.
#
# Sourced by the build scripts so CI and a laptop pass exactly the same set.
# Every variable is optional: unset ones are omitted, and the offline build
# omits all of them, which is what makes `cloudAvailable` false.
set -euo pipefail

emit() {
  local name="$1" value="${2:-}"
  [[ -n "$value" ]] && printf -- '--dart-define=%s=%s\n' "$name" "$value"
  return 0
}

emit SUPABASE_URL "${SUPABASE_URL:-}"
emit SUPABASE_ANON_KEY "${SUPABASE_ANON_KEY:-}"
emit INVITE_BASE_URL "${INVITE_BASE_URL:-}"
emit SITE_URL "${SITE_URL:-}"
emit FCM_VAPID_KEY "${FCM_VAPID_KEY:-}"
emit FIREBASE_API_KEY "${FIREBASE_API_KEY:-}"
emit FIREBASE_AUTH_DOMAIN "${FIREBASE_AUTH_DOMAIN:-}"
emit FIREBASE_PROJECT_ID "${FIREBASE_PROJECT_ID:-}"
emit FIREBASE_STORAGE_BUCKET "${FIREBASE_STORAGE_BUCKET:-}"
emit FIREBASE_MESSAGING_SENDER_ID "${FIREBASE_MESSAGING_SENDER_ID:-}"
emit FIREBASE_APP_ID "${FIREBASE_APP_ID:-}"
