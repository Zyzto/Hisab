#!/usr/bin/env bash
# Run local-only integration tests on web using Chrome.
# Starts ChromeDriver automatically via npm (no global chromedriver needed), then runs
# flutter drive; the tests run in Chrome.
#
# Prerequisites: Node/npm (for chromedriver), Flutter, Chrome installed.
#
# Usage: ./scripts/run_web_integration_tests.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

CHROMEDRIVER_PORT="${CHROMEDRIVER_PORT:-4444}"
CHROMEDRIVER_PID=""

kill_webdriver_on_port() {
  if command -v fuser &>/dev/null; then
    fuser -k "${CHROMEDRIVER_PORT}/tcp" >/dev/null 2>&1 || true
    return
  fi

  if command -v lsof &>/dev/null; then
    local pids
    pids=$(lsof -ti ":${CHROMEDRIVER_PORT}" 2>/dev/null || true)
    if [ -n "$pids" ]; then
      # shellcheck disable=SC2086
      kill $pids 2>/dev/null || true
    fi
  fi
}

# Free port if something is still bound from a previous run
kill_webdriver_on_port
sleep 1

cleanup() {
  local exit_code=$?
  if [ -n "$CHROMEDRIVER_PID" ] && kill -0 "$CHROMEDRIVER_PID" 2>/dev/null; then
    echo "==> Stopping ChromeDriver (PID $CHROMEDRIVER_PID)..."
    kill "$CHROMEDRIVER_PID" 2>/dev/null || true
  fi
  kill_webdriver_on_port
  exit "$exit_code"
}
trap cleanup EXIT

# Prefer local/global chromedriver first; fallback to npx ephemeral install.
echo "==> Starting ChromeDriver on port $CHROMEDRIVER_PORT..."
if command -v chromedriver &>/dev/null; then
  chromedriver --port="$CHROMEDRIVER_PORT" &
  CHROMEDRIVER_PID=$!
elif command -v npx &>/dev/null; then
  npx --yes chromedriver@latest --port="$CHROMEDRIVER_PORT" &
  CHROMEDRIVER_PID=$!
else
  echo "ERROR: chromedriver not found and npx is unavailable."
  echo "Install chromedriver or Node.js/npm, then rerun."
  exit 1
fi

# Wait for ChromeDriver to listen (give it a moment to bind)
sleep 2
for i in $(seq 1 20); do
  if curl -s --connect-timeout 2 "http://127.0.0.1:$CHROMEDRIVER_PORT/status" &>/dev/null; then
    break
  fi
  if [ "$i" -eq 20 ]; then
    echo "ERROR: ChromeDriver did not become ready on port $CHROMEDRIVER_PORT (is another process using it?)"
    exit 1
  fi
  sleep 1
done

echo "==> Running integration tests in Chrome..."
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d web-server \
  --release \
  --web-browser-flag=--no-sandbox \
  --web-browser-flag=--disable-dev-shm-usage
