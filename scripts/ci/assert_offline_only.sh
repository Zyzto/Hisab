#!/usr/bin/env bash
# Guard the public repository against reintroducing hosted-service code.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

fail=0
check_absent() {
  local pattern="$1"
  local scope="$2"
  if rg -n -i --glob '*.dart' --glob '!**/*.g.dart' "$pattern" $scope; then
    echo "❌ Forbidden public reference: $pattern" >&2
    fail=1
  fi
}

check_absent 'package:(hisab_backend|hisab_cloud|firebase_|supabase|revenuecat|paddle|url_launcher|connectivity_plus|langchain_|upgrader|in_app_update|app_links)' 'lib test integration_test packages'
check_absent '\b(CloudBackend|CloudBilling|RevenueCat|Paddle|Supabase|Firebase|DataSyncService|SyncEngine|telemetry)\b' 'lib test integration_test packages'

check_platform_absent() {
  local pattern="$1"
  local scope=(
    android/app/build.gradle.kts
    android/app/src
    android/settings.gradle.kts
    ios/Runner
    ios/Runner.xcodeproj
    web/index.html
    web/manifest.json
    pubspec.yaml
  )
  if rg -n -i "$pattern" "${scope[@]}"; then
    echo "❌ Forbidden public platform/config reference: $pattern" >&2
    fail=1
  fi
}

check_platform_absent 'firebase|supabase|revenuecat|paddle|google-services|google_sign_in|url_launcher|connectivity_plus|langchain_|upgrader|in_app_update|app_links|oauth'
check_platform_absent "create\\([\"']cloud|src/cloud|flavor[[:space:]]*=[[:space:]]*[\"']cloud"

if rg -n -i --glob 'pubspec*.yaml' 'hisab_backend|hisab_cloud|firebase|supabase|revenuecat|paddle|url_launcher|connectivity|langchain|upgrader|in_app_update|app_links|http:' pubspec.yaml packages; then
  echo "❌ Hosted-service dependency found in public pubspec files" >&2
  fail=1
fi

private_package_present=0
while IFS= read -r private_file; do
  if [[ -e "$private_file" ]]; then
    echo "$private_file"
    private_package_present=1
  fi
done < <(git ls-files -- 'packages/hisab_backend/**' 'packages/hisab_cloud/**')
if [[ "$private_package_present" -ne 0 ]]; then
  echo "❌ Private package source remains in the public repository" >&2
  fail=1
fi

for path in android/app/src/cloud android/app/src/cloudDebug web/firebase-messaging-sw.js \
  web/redirect.html web/invite-redirect-template.html web/.well-known; do
  if [[ -e "$path" ]]; then
    echo "❌ Cloud-only platform asset remains: $path" >&2
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "✅ Public tree is local-only"
