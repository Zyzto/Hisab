#!/usr/bin/env bash
# Validate/build the local-only iOS application without signing credentials.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS builds require macOS with Xcode; no iOS build was attempted" >&2
  exit 2
fi

bash scripts/ci/assert_offline_only.sh
flutter build ios --release --no-codesign
