#!/usr/bin/env bash
# Stage local legal, SEO, and PowerSync assets beside the Flutter web bundle.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

cp -r web/privacy build/web/
cp -r web/delete-account build/web/
cp -r web/ar build/web/
cp -r web/features build/web/
cp -r web/images build/web/
cp web/seo.css build/web/
cp web/robots.txt build/web/
cp web/sitemap.xml build/web/
mkdir -p build/web/icons
cp web/icons/favicon-32.png web/icons/favicon-48.png build/web/icons/

cp web/sqlite3.wasm build/web/ 2>/dev/null || true
for f in web/*.worker.js; do
  [[ -f "$f" ]] && cp "$f" build/web/
done

echo "Staged local web assets into build/web"
