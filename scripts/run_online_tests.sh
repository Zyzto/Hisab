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

# Prefer rootful Podman (Kong fails under rootless on NixOS). Then rootless.
if [[ -z "${DOCKER_HOST:-}" ]]; then
  if [[ -S /run/podman/podman.sock ]]; then
    export DOCKER_HOST="unix:///run/podman/podman.sock"
  elif [[ -n "${XDG_RUNTIME_DIR:-}" && -S "${XDG_RUNTIME_DIR}/podman/podman.sock" ]]; then
    export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
  elif [[ -S "/run/user/$(id -u)/podman/podman.sock" ]]; then
    export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
  fi
fi

SB() {
  if command -v supabase >/dev/null 2>&1; then
    command supabase "$@"
    return
  fi
  if [[ -e /etc/NIXOS ]] || grep -q '^ID=nixos' /etc/os-release 2>/dev/null; then
    if command -v nix >/dev/null 2>&1; then
      nix --extra-experimental-features 'nix-command flakes' \
        shell nixpkgs#supabase-cli -c supabase "$@"
      return
    fi
  fi
  if command -v npx >/dev/null 2>&1; then
    npx supabase "$@"
    return
  fi
  echo "ERROR: Supabase CLI not found" >&2
  return 1
}

SUPABASE_STARTED=0
SUPABASE_WAS_RUNNING=0
WEBDRIVER_STARTED=0
WEBDRIVER_PID=""
WEBDRIVER_PORT="${WEBDRIVER_PORT:-4444}"

kill_webdriver_on_port() {
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "${WEBDRIVER_PORT}/tcp" >/dev/null 2>&1 || true
    return
  fi

  if command -v lsof >/dev/null 2>&1; then
    local pids
    pids="$(lsof -ti ":${WEBDRIVER_PORT}" 2>/dev/null || true)"
    if [ -n "$pids" ]; then
      # shellcheck disable=SC2086
      kill $pids 2>/dev/null || true
    fi
  fi
}

webdriver_ready() {
  if ! command -v curl >/dev/null 2>&1; then
    return 1
  fi
  curl --silent --show-error --fail "http://127.0.0.1:${WEBDRIVER_PORT}/status" >/dev/null 2>&1
}

ensure_webdriver() {
  if [ "$PLATFORM" != "web" ]; then
    return
  fi

  # Fresh WebDriver per run avoids stale-session crashes in flutter drive.
  kill_webdriver_on_port
  sleep 1

  echo "==> Starting WebDriver on port ${WEBDRIVER_PORT}..."
  if command -v chromedriver >/dev/null 2>&1; then
    chromedriver --port="${WEBDRIVER_PORT}" >/tmp/hisab-chromedriver.log 2>&1 &
  elif command -v npx >/dev/null 2>&1; then
    npx --yes chromedriver@latest --port="${WEBDRIVER_PORT}" >/tmp/hisab-chromedriver.log 2>&1 &
  else
    echo "ERROR: chromedriver not found and npx is unavailable."
    echo "Install chromedriver or Node.js/npm, then rerun."
    exit 1
  fi

  WEBDRIVER_PID=$!
  WEBDRIVER_STARTED=1

  for _ in {1..20}; do
    if webdriver_ready; then
      echo "==> WebDriver is ready."
      return
    fi
    sleep 1
  done

  echo "ERROR: WebDriver did not become ready on http://127.0.0.1:${WEBDRIVER_PORT}/status"
  if [ -f /tmp/hisab-chromedriver.log ]; then
    echo "Last WebDriver logs:"
    sed -n '1,120p' /tmp/hisab-chromedriver.log
  fi
  exit 1
}

cleanup() {
  local exit_code=$?
  if [ "$WEBDRIVER_STARTED" -eq 1 ] && [ -n "$WEBDRIVER_PID" ]; then
    kill "$WEBDRIVER_PID" >/dev/null 2>&1 || true
    kill_webdriver_on_port
  fi
  # Only stop if we started a fresh stack (do not tear down an existing local env).
  if [ "$SUPABASE_STARTED" -eq 1 ] && [ "$SUPABASE_WAS_RUNNING" -eq 0 ]; then
    echo "==> Stopping local Supabase..."
    SB stop || echo "WARN: supabase stop failed"
  fi
  exit "$exit_code"
}
trap cleanup EXIT

echo "==> Verifying Supabase config-as-code invariants..."
bash ./scripts/verify_supabase_config_as_code.sh

echo "==> DOCKER_HOST=${DOCKER_HOST:-unset}"
if curl -sf --connect-timeout 1 --max-time 2 \
  "http://127.0.0.1:54321/auth/v1/health" >/dev/null 2>&1; then
  SUPABASE_WAS_RUNNING=1
  echo "==> Reusing already-running local Supabase"
else
  echo "==> Starting local Supabase..."
  # Prefer excluding analytics helpers; keep Kong/API. Avoid tearing down Studio
  # ports if the developer is using them — start with logflare/vector excluded.
  SB start -x logflare,vector --ignore-health-check || \
    SB start -x logflare,vector --ignore-health-check
  SUPABASE_STARTED=1
fi

# Extract credentials without requiring jq
status_env="$(SB status -o env 2>/dev/null || true)"
SUPABASE_URL="$(printf '%s\n' "$status_env" | sed -n 's/^API_URL=//p' | tr -d '"')"
SUPABASE_ANON_KEY="$(printf '%s\n' "$status_env" | sed -n 's/^ANON_KEY=//p' | tr -d '"')"

if [ -z "$SUPABASE_URL" ] || [ "$SUPABASE_URL" = "null" ]; then
  echo "ERROR: Could not get SUPABASE_URL from supabase status"
  exit 1
fi

echo "==> Resetting database (apply migrations + seed)..."
SB db reset

echo "==> Running online integration tests (platform=$PLATFORM)..."
echo "    SUPABASE_URL=$SUPABASE_URL"

# Invite suite is compile-time gated (bool.fromEnvironment); env alone is ignored.
SKIP_INVITE="${HISAB_SKIP_INVITE_ONLINE:-false}"
echo "    HISAB_SKIP_INVITE_ONLINE=$SKIP_INVITE"

if [ "$PLATFORM" = "web" ]; then
  ensure_webdriver
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/online_app_test.dart \
    -d web-server --release \
    --dart-define="SUPABASE_URL=$SUPABASE_URL" \
    --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
    --dart-define="HISAB_SKIP_INVITE_ONLINE=$SKIP_INVITE"
else
  flutter test integration_test/online_app_test.dart \
    -d "$PLATFORM" \
    --dart-define="SUPABASE_URL=$SUPABASE_URL" \
    --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
    --dart-define="HISAB_SKIP_INVITE_ONLINE=$SKIP_INVITE"
fi
