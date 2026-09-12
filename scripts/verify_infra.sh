#!/usr/bin/env bash
# Release-readiness checks for the public local-only client.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "❌ $1" >&2
  exit 1
}

echo "==> Checking local-only web shell"
for f in web/index.html web/flutter_bootstrap.js web/manifest.json \
  web/privacy/index.html web/delete-account/index.html \
  web/ar/privacy/index.html web/ar/delete-account/index.html \
  web/ar/index.html web/features/index.html \
  web/robots.txt web/sitemap.xml; do
  [[ -f "$f" ]] || fail "Missing web asset: $f"
done
grep -q '_flutter.loader.load' web/flutter_bootstrap.js || \
  fail "web/flutter_bootstrap.js does not load Flutter"
if rg -n -i 'firebase|supabase|invite|oauth|\bcloud\b|\bpush[[:space:]]+notification' web/index.html web/flutter_bootstrap.js web/manifest.json; then
  fail "web shell contains a removed online integration"
fi

echo "==> Checking version and toolchain pins"
version_line=$(grep -E '^version:' pubspec.yaml | head -1 || true)
[[ -n "$version_line" ]] || fail "pubspec.yaml missing version:"
echo "$version_line" | grep -Eq '^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$' || \
  fail "pubspec.yaml version must be MARKETING+BUILD"
[[ -f .flutter-version ]] || fail "Missing .flutter-version"

echo "==> Checking FOSS Android target"
grep -q 'create("foss")' android/app/build.gradle.kts || \
  fail "Android FOSS flavor is missing"
if grep -q 'create("cloud")\|google-services\|firebase' android/app/build.gradle.kts android/settings.gradle.kts; then
  fail "Android build contains a cloud service configuration"
fi
[[ ! -e android/app/src/cloud ]] || fail "Cloud Android resources remain in the public tree"
[[ ! -e android/app/src/cloudDebug ]] || fail "Cloud debug Android resources remain in the public tree"

echo "==> Checking static site assets"
for f in web/images/welcome.png web/images/groups.png web/images/add-expense.png \
  web/images/settlement.png web/icons/favicon-32.png web/icons/favicon-48.png; do
  [[ -f "$f" ]] || fail "Missing $f"
done

echo "✅ Public infrastructure check passed"
