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

# Free port if something is still bound from a previous run
if command -v fuser &>/dev/null; then
  fuser -k "$CHROMEDRIVER_PORT/tcp" 2>/dev/null || true
  sleep 1
elif command -v lsof &>/dev/null; then
  pid=$(lsof -ti ":$CHROMEDRIVER_PORT" 2>/dev/null) && kill $pid 2>/dev/null || true
  sleep 1
fi

cleanup() {
  local exit_code=$?
  if [ -n "$CHROMEDRIVER_PID" ] && kill -0 "$CHROMEDRIVER_PID" 2>/dev/null; then
    echo "==> Stopping ChromeDriver (PID $CHROMEDRIVER_PID)..."
    kill "$CHROMEDRIVER_PID" 2>/dev/null || true
  fi
  exit "$exit_code"
}
trap cleanup EXIT

# Prefer npx chromedriver (from project's node_modules) so no global install is needed
if command -v npx &>/dev/null && [ -f "package.json" ]; then
  echo "==> Installing npm deps (chromedriver) if needed..."
  npm install --no-audit --no-fund
  echo "==> Starting ChromeDriver on port $CHROMEDRIVER_PORT (Chrome will be used for tests)..."
  npx chromedriver --port="$CHROMEDRIVER_PORT" &
  CHROMEDRIVER_PID=$!
else
  echo "==> Starting ChromeDriver on port $CHROMEDRIVER_PORT..."
  if ! command -v chromedriver &>/dev/null; then
    echo "ERROR: chromedriver not found. Either:"
    echo "  1. Run from project root after 'npm install' (uses npx chromedriver), or"
    echo "  2. Install ChromeDriver and ensure it is on PATH (see test/README.md)."
    exit 1
  fi
  chromedriver --port="$CHROMEDRIVER_PORT" &
  CHROMEDRIVER_PID=$!
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
