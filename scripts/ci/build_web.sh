#!/usr/bin/env bash
# Build the local-only web bundle. No keys or environment variables are used.
#
# Usage: scripts/ci/build_web.sh [--wasm]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

WASM_FLAG=()
BUILD_FLAGS=(--no-wasm-dry-run)
if [[ "${1:-}" == "--wasm" ]]; then
  WASM_FLAG=(--wasm)
  BUILD_FLAGS=()
fi

flutter pub run powersync:setup_web
test -f web/sqlite3.wasm
test -f web/powersync_db.worker.js

echo "Compiling local-only web bundle..."
flutter build web \
  "${WASM_FLAG[@]}" \
  "${BUILD_FLAGS[@]}" \
  --dart-define=ENABLE_WEB_SEMANTICS=false

bash scripts/ci/stage_web_static.sh
echo "Built build/web"
