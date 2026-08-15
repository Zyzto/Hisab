#!/usr/bin/env bash
# Build the web bundle and stage everything Firebase Hosting serves beside it.
#
#   scripts/ci/build_web.sh [--wasm]
#
# Configuration comes from the environment (scripts/ci/dart_defines.sh). With
# nothing set this produces the offline build.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

WASM_FLAG=()
[[ "${1:-}" == "--wasm" ]] && WASM_FLAG=(--wasm)

# PowerSync's web worker and sqlite3.wasm are downloaded, not vendored. Without
# them the live site fails on a wrong-MIME script load rather than anything
# that names the missing file.
flutter pub run powersync:setup_web
test -f web/sqlite3.wasm || { echo "Missing web/sqlite3.wasm after setup_web" >&2; exit 1; }
test -f web/powersync_db.worker.js || { echo "Missing web/powersync_db.worker.js after setup_web" >&2; exit 1; }

mapfile -t defines < <(bash scripts/ci/dart_defines.sh)

flutter build web \
  "${WASM_FLAG[@]}" \
  --dart-define=ENABLE_WEB_SEMANTICS=false \
  "${defines[@]}"

bash scripts/ci/stage_web_static.sh
bash scripts/ci/inject_firebase_web_config.sh

echo "Built build/web"
