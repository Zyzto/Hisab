#!/usr/bin/env bash
# Run online integration tests against a local Supabase instance.
#
# Prerequisites:
#   - Docker running
#   - Supabase CLI installed (supabase --version)
#
# Usage:
#   ./scripts/run_online_tests.sh            # web (default)
#   ./scripts/run_online_tests.sh android    # android device
set -euo pipefail

PLATFORM="${1:-web}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

echo "==> Starting local Supabase..."
supabase start

# Extract credentials from the running instance
SUPABASE_URL=$(supabase status --output json | jq -r '.API_URL')
SUPABASE_ANON_KEY=$(supabase status --output json | jq -r '.ANON_KEY')

if [ -z "$SUPABASE_URL" ] || [ "$SUPABASE_URL" = "null" ]; then
  echo "ERROR: Could not get SUPABASE_URL from supabase status"
  exit 1
fi

echo "==> Resetting database (apply migrations + seed)..."
supabase db reset

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

RESULT=$?

echo "==> Stopping local Supabase..."
supabase stop

exit $RESULT
