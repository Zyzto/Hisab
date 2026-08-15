#!/usr/bin/env bash
# Place google-services.json in the cloud source set.
#
# Only the cloud flavor has Firebase, and only a build that supplies
# GOOGLE_SERVICES_JSON can produce it. Without the variable this exits 0: the
# foss flavor has no Firebase, and android/app/build.gradle.kts skips the
# google-services plugin entirely when the file is absent.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${GOOGLE_SERVICES_JSON:-}" ]]; then
  echo "GOOGLE_SERVICES_JSON not set — skipping (foss builds do not need it)"
  exit 0
fi

mkdir -p android/app/src/cloud
echo "$GOOGLE_SERVICES_JSON" | base64 --decode > android/app/src/cloud/google-services.json
echo "Wrote android/app/src/cloud/google-services.json"
