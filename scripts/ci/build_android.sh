#!/usr/bin/env bash
# Build the local-only Android APK set.
#
# Usage: scripts/ci/build_android.sh [release|debug]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ "${1:-}" == "release" || "${1:-}" == "debug" ]]; then
  MODE="$1"
else
  MODE="${2:-release}"
fi
if [[ "$MODE" != "release" && "$MODE" != "debug" ]]; then
  echo "usage: $0 [release|debug]" >&2
  exit 2
fi

extra=()
if [[ "$MODE" == "release" ]]; then
  bash "$ROOT_DIR/scripts/ci/decode_keystore.sh" release
  symbols_dir="$ROOT_DIR/build/app/outputs/symbols"
  extra=(--obfuscate --split-debug-info="$symbols_dir" --tree-shake-icons)
else
  bash "$ROOT_DIR/scripts/ci/decode_keystore.sh" debug
fi

flutter build apk "--$MODE" --flavor foss --split-per-abi "${extra[@]}"
echo "Built FOSS $MODE APKs in build/app/outputs/flutter-apk/"
