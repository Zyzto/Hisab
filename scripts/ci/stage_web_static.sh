#!/usr/bin/env bash
# Copy the hand-written pages and runtime assets into build/web.
#
# `flutter build web` only emits the app bundle; the privacy page, the
# account-deletion page, Arabic/features landings, crawl files, the App Link
# well-known files and the PowerSync worker all have to be placed next to it.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

cp -r web/privacy build/web/
cp -r web/delete-account build/web/
cp -r web/ar build/web/
cp -r web/features build/web/
cp -r web/images build/web/
cp web/seo.css build/web/
cp web/robots.txt build/web/
cp web/sitemap.xml build/web/
cp -r web/.well-known build/web/
cp web/redirect.html build/web/
cp web/in_app_browser.js build/web/
cp web/og-invite.png build/web/
mkdir -p build/web/icons
cp web/icons/favicon-32.png web/icons/favicon-48.png build/web/icons/

# The invite hand-off page only makes sense with a backend behind it. An
# offline build skips it rather than deploying a page that redirects nowhere.
if [[ -n "${CLOUD_INVITE_RESOLVER_URL:-}" ]]; then
  sed "s|__CLOUD_INVITE_RESOLVER_URL__|${CLOUD_INVITE_RESOLVER_URL}|g" \
    web/invite-redirect-template.html > build/web/invite-redirect.html
  echo "Staged invite-redirect.html"
else
  echo "CLOUD_INVITE_RESOLVER_URL not set — skipping invite-redirect.html"
fi

cp web/sqlite3.wasm build/web/ 2>/dev/null || true
for f in web/*.worker.js; do
  [[ -f "$f" ]] && cp "$f" build/web/
done

mkdir -p build
cp firebase.json build/firebase.json
python3 scripts/ci/apply_staging_seo.py

echo "Staged static assets into build/web"
