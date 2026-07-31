#!/usr/bin/env bash
# Infra / release-readiness checks (repo layout + config-as-code).
# Safe to run locally and in CI — no network required.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "❌ $1" >&2
  exit 1
}

echo "==> Infra check"

# ── Supabase config-as-code ───────────────────────────────────────────────────
bash ./scripts/verify_supabase_config_as_code.sh

# ── Required Edge Functions ───────────────────────────────────────────────────
echo "==> Checking Edge Function sources"
required_fns=(
  invite-redirect
  og-invite-image
  send-notification
  telemetry
)
for fn in "${required_fns[@]}"; do
  [[ -f "supabase/functions/$fn/index.ts" ]] \
    || fail "Missing Edge Function source: supabase/functions/$fn/index.ts"
done

# ── Firebase Hosting layout ───────────────────────────────────────────────────
echo "==> Checking Firebase Hosting config"
[[ -f firebase.json ]] || fail "Missing firebase.json"
grep -q '"hosting"' firebase.json || fail "firebase.json missing hosting block"
grep -q '"public"[[:space:]]*:[[:space:]]*"build/web"' firebase.json \
  || fail 'firebase.json hosting.public must be "build/web"'
grep -q 'invite-redirect' firebase.json \
  || fail "firebase.json missing invite-redirect rewrite"

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

# ── App version + CI Flutter pin ──────────────────────────────────────────────
echo "==> Checking version / CI pins"
version_line=$(grep -E '^version:' pubspec.yaml | head -1 || true)
[[ -n "$version_line" ]] || fail "pubspec.yaml missing version:"
if ! echo "$version_line" | grep -Eq '^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$'; then
  fail "pubspec.yaml version must be MARKETING+BUILD (e.g. 0.6.16+65); got: $version_line"
fi

[[ -f .github/workflows/release.yml ]] || fail "Missing .github/workflows/release.yml"
grep -q 'FLUTTER_VERSION:' .github/workflows/release.yml \
  || fail "release.yml missing FLUTTER_VERSION env"

# ── Privacy / Play disclosure pages (Hosting copies these) ────────────────────
echo "==> Checking static legal pages"
[[ -d web/privacy ]] || fail "Missing web/privacy/"
[[ -d web/delete-account ]] || fail "Missing web/delete-account/"

# ── Notification pipeline coupling (migration + edge source both present) ─────
echo "==> Checking notification pipeline files"
ls supabase/migrations/*notify_group_activity* >/dev/null 2>&1 \
  || fail "Missing notify_group_activity migration(s)"
grep -q 'expense_deleted' supabase/functions/send-notification/index.ts \
  || fail "send-notification missing expense_deleted action support"

echo "✅ Infra check passed"
