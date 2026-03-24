#!/usr/bin/env bash
# Run online integration tests against a local Supabase instance.
#
# Prerequisites:
#   - Docker or Podman (Supabase CLI uses the Docker API; Podman: see docs/SUPABASE_SETUP.md)
#   - Supabase CLI installed (supabase --version) or npx supabase
#
# Usage:
#   ./scripts/run_online_tests.sh            # web (default)
#   ./scripts/run_online_tests.sh android    # android device
set -euo pipefail

PLATFORM="${1:-web}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

SB() { command -v supabase >/dev/null 2>&1 && supabase "$@" || npx supabase "$@"; }

# Rootless Podman: point Supabase at the user socket when DOCKER_HOST is unset.
if [[ -z "${DOCKER_HOST:-}" ]]; then
  if [[ -n "${XDG_RUNTIME_DIR:-}" && -S "${XDG_RUNTIME_DIR}/podman/podman.sock" ]]; then
    export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
  elif [[ -S "/run/user/$(id -u)/podman/podman.sock" ]]; then
    export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
  fi
fi

SUPABASE_STARTED=0
cleanup() {
  local exit_code=$?
  if [ "$SUPABASE_STARTED" -eq 1 ]; then
    echo "==> Stopping local Supabase..."
    SB stop || echo "WARN: supabase stop failed"
  fi
  exit "$exit_code"
}
trap cleanup EXIT

echo "==> Verifying Supabase config-as-code invariants..."
bash ./scripts/verify_supabase_config_as_code.sh

echo "==> Starting local Supabase..."
SB start
SUPABASE_STARTED=1

# Extract credentials from the running instance
SUPABASE_URL=$(SB status --output json | jq -r '.API_URL')
SUPABASE_ANON_KEY=$(SB status --output json | jq -r '.ANON_KEY')

if [ -z "$SUPABASE_URL" ] || [ "$SUPABASE_URL" = "null" ]; then
  echo "ERROR: Could not get SUPABASE_URL from supabase status"
  exit 1
fi

echo "==> Resetting database (apply migrations + seed)..."
SB db reset

echo "==> Running online integration tests (platform=$PLATFORM)..."
echo "    SUPABASE_URL=$SUPABASE_URL"

if [ "$PLATFORM" = "web" ]; then
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/online_app_test.dart \
    -d web-server --release \
    --dart-define="SUPABASE_URL=$SUPABASE_URL" \
    --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
else
  flutter test integration_test/online_app_test.dart \
    -d "$PLATFORM" \
    --dart-define="SUPABASE_URL=$SUPABASE_URL" \
    --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
fi
