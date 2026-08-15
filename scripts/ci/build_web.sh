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
# A JS build still runs a dart2wasm dry run whose only output is advice about
# packages we do not control. Skipping it is worth ~30s per build.
BUILD_FLAGS=(--no-wasm-dry-run)
if [[ "${1:-}" == "--wasm" ]]; then
  WASM_FLAG=(--wasm)
  BUILD_FLAGS=()
fi

# PowerSync's web worker and sqlite3.wasm are downloaded, not vendored. Without
# them the live site fails on a wrong-MIME script load rather than anything
# that names the missing file.
flutter pub run powersync:setup_web
test -f web/sqlite3.wasm || { echo "Missing web/sqlite3.wasm after setup_web" >&2; exit 1; }
test -f web/powersync_db.worker.js || { echo "Missing web/powersync_db.worker.js after setup_web" >&2; exit 1; }

mapfile -t defines < <(bash scripts/ci/dart_defines.sh)

# Flutter only flushes its progress spinner on a TTY, so on CI this step prints
# nothing for minutes. Bracket it so a slow compile is not read as a hang.
echo "Compiling web bundle (no output until dart2js finishes)..."
SECONDS=0

flutter build web \
  "${WASM_FLAG[@]}" \
  "${BUILD_FLAGS[@]}" \
  --dart-define=ENABLE_WEB_SEMANTICS=false \
  "${defines[@]}"

echo "Compiled web bundle in ${SECONDS}s"

bash scripts/ci/stage_web_static.sh
bash scripts/ci/inject_firebase_web_config.sh

echo "Built build/web"
