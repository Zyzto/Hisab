#!/usr/bin/env bash
# Release-readiness checks over the client tree (layout, web shell, pins).
# Safe to run locally and in CI — no network required.
#
# Backend-side checks (edge functions, config-as-code, the notification
# pipeline) live in the private cloud repo's copy of this script.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "❌ $1" >&2
  exit 1
}

echo "==> Infra check"

# ── Firebase Hosting layout ───────────────────────────────────────────────────
echo "==> Checking Firebase Hosting config"
[[ -f firebase.json ]] || fail "Missing firebase.json"
grep -q '"hosting"' firebase.json || fail "firebase.json missing hosting block"
grep -q '"public"[[:space:]]*:[[:space:]]*"build/web"' firebase.json \
  || fail 'firebase.json hosting.public must be "build/web"'
# Every invite link ever shared points at /functions/v1/invite-redirect, so
# that rewrite has to keep serving no matter what the newer /invite-redirect
# route does.
grep -q '/functions/v1/invite-redirect' firebase.json \
  || fail "firebase.json dropped the legacy invite-redirect rewrite"

# ── Web PWA shell ─────────────────────────────────────────────────────────────
echo "==> Checking web shell assets"
for f in web/index.html web/flutter_bootstrap.js web/manifest.json \
  web/invite-redirect-template.html web/redirect.html web/in_app_browser.js; do
  [[ -f "$f" ]] || fail "Missing web asset: $f"
done
grep -q '__hisabFirebaseReady\|__FIREBASE_' web/index.html \
  || fail "web/index.html missing Firebase ready/placeholder wiring"
grep -q 'in_app_browser.js' web/index.html \
  || fail "web/index.html missing in_app_browser.js gate"
grep -q '__hisabInAppBlocked' web/index.html \
  || fail "web/index.html missing __hisabInAppBlocked gate"
grep -q 'HisabInApp' web/redirect.html \
  || fail "web/redirect.html missing HisabInApp gate"
grep -q 'isInAppBrowser' web/in_app_browser.js \
  || fail "web/in_app_browser.js missing isInAppBrowser"
grep -q '_flutter.loader.load' web/flutter_bootstrap.js \
  || fail "web/flutter_bootstrap.js missing _flutter.loader.load()"

# ── App version + Flutter pin ─────────────────────────────────────────────────
echo "==> Checking version / toolchain pins"
version_line=$(grep -E '^version:' pubspec.yaml | head -1 || true)
[[ -n "$version_line" ]] || fail "pubspec.yaml missing version:"
if ! echo "$version_line" | grep -Eq '^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$'; then
  fail "pubspec.yaml version must be MARKETING+BUILD (e.g. 0.6.16+65); got: $version_line"
fi

# One file, read by every workflow in both repos and by the local pipeline.
# The previous "keep in sync" comments across four copies did not survive the
# split.
[[ -f .flutter-version ]] || fail "Missing .flutter-version"
grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' .flutter-version \
  || fail ".flutter-version must contain a bare version like 3.41.5"
if grep -rn 'FLUTTER_VERSION:' .github/workflows/ >/dev/null 2>&1; then
  fail "A workflow still pins FLUTTER_VERSION; read .flutter-version instead"
fi

# ── Android variants ──────────────────────────────────────────────────────────
echo "==> Checking Android flavors"
grep -q 'create("foss")' android/app/build.gradle.kts \
  || fail "android/app/build.gradle.kts missing the foss flavor"
grep -q 'create("cloud")' android/app/build.gradle.kts \
  || fail "android/app/build.gradle.kts missing the cloud flavor"
[[ -f android/app/src/cloud/AndroidManifest.xml ]] \
  || fail "Missing android/app/src/cloud/AndroidManifest.xml (deep link filters)"

# ── Privacy / Play disclosure pages (Hosting copies these) ────────────────────
echo "==> Checking static legal pages"
[[ -d web/privacy ]] || fail "Missing web/privacy/"
[[ -d web/delete-account ]] || fail "Missing web/delete-account/"
[[ -d web/ar ]] || fail "Missing web/ar/"
[[ -d web/features ]] || fail "Missing web/features/"
[[ -f web/seo.css ]] || fail "Missing web/seo.css"
[[ -f web/robots.txt ]] || fail "Missing web/robots.txt"
[[ -f web/sitemap.xml ]] || fail "Missing web/sitemap.xml"
for f in web/images/welcome.png web/images/welcome-ar.png \
  web/images/groups.png web/images/groups-ar.png \
  web/images/add-expense.png web/images/add-expense-ar.png \
  web/images/settlement.png web/images/settlement-ar.png \
  web/images/og-en.png web/images/og-ar.png \
  web/icons/favicon-32.png web/icons/favicon-48.png; do
  [[ -f "$f" ]] || fail "Missing $f"
done
grep -q 'Allow: /' web/robots.txt || fail "web/robots.txt must allow production crawlers"
grep -q 'Sitemap: https://hisab.shenepoy.com/sitemap.xml' web/robots.txt \
  || fail "web/robots.txt must point at the production sitemap"
if grep -q 'test.hisab.shenepoy.com' web/sitemap.xml web/robots.txt; then
  fail "committed crawl files must not mention the staging host"
fi
grep -q 'https://hisab.shenepoy.com/' web/sitemap.xml \
  || fail "web/sitemap.xml must list the production origin"
[[ -f scripts/ci/apply_staging_seo.py ]] || fail "Missing scripts/ci/apply_staging_seo.py"
if grep -q 'X-Robots-Tag' firebase.json; then
  fail "committed firebase.json must not set X-Robots-Tag (staging writes a copy under build/)"
fi
python3 scripts/ci/apply_staging_seo.py --selftest

echo "✅ Infra check passed"
