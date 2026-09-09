#!/usr/bin/env bash
# Build the Android APK set and, for a cloud release, an App Bundle.
#
#   scripts/ci/build_android.sh [foss|cloud] [release|debug]
#
# Defaults to the foss release, the variant the public repo ships. The debug
# build type appends `.debug` to the application id, which is how staging
# installs beside production instead of over it.
#
# Signing and Firebase config come from the environment via the two decode
# scripts; build-time configuration comes from scripts/ci/dart_defines.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

FLAVOR="${1:-foss}"
MODE="${2:-release}"
if [[ "$FLAVOR" != "foss" && "$FLAVOR" != "cloud" ]]; then
  echo "usage: $0 [foss|cloud] [release|debug]" >&2
  exit 2
fi
if [[ "$MODE" != "release" && "$MODE" != "debug" ]]; then
  echo "usage: $0 [foss|cloud] [release|debug]" >&2
  exit 2
fi

bash scripts/ci/decode_keystore.sh
bash scripts/ci/decode_google_services.sh

# Obfuscation and split debug info only apply to a release build.
extra=()
if [[ "$MODE" == "release" ]]; then
  # Use an absolute path so the symbol files are always written to the
  # directory the private cloud pipeline archives and checks.
  SYMBOLS_DIR="$ROOT_DIR/build/app/outputs/symbols"
  extra=(--obfuscate --split-debug-info="$SYMBOLS_DIR" --tree-shake-icons)
fi

# Keep the Dart redirect and the Android manifest on the same scheme. Debug
# builds are the staging/test identity and must never claim production links.
if [[ -z "${HISAB_AUTH_SCHEME:-}" ]]; then
  if [[ "$MODE" == "debug" ]]; then
    export HISAB_AUTH_SCHEME="com.shenepoy.hisab.debug"
  else
    export HISAB_AUTH_SCHEME="com.shenepoy.hisab"
  fi
fi

mapfile -t defines < <(bash scripts/ci/dart_defines.sh)

flutter build apk "--$MODE" --flavor "$FLAVOR" --split-per-abi "${extra[@]}" "${defines[@]}"

# Only a cloud release goes to Play; the foss variant ships as APKs from the
# public repo's releases, and staging is sideloaded.
if [[ "$FLAVOR" == "cloud" && "$MODE" == "release" ]]; then
  flutter build appbundle --release --flavor cloud "${extra[@]}" "${defines[@]}"
fi

echo "Built $FLAVOR $MODE APKs in build/app/outputs/flutter-apk/"
