#!/usr/bin/env bash
# POST a test payload to local Edge Function send-notification.
# Requires: local_test_env up, FCM secrets loaded (reload-secrets), and
# device tokens registered in local Supabase for the target group members.
#
# Usage:
#   ./scripts/local_send_test_notification.sh <group_id> <actor_user_id>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

GROUP_ID="${1:-}"
ACTOR_ID="${2:-}"
if [[ -z "$GROUP_ID" || -z "$ACTOR_ID" ]]; then
  echo "Usage: $0 <group_id> <actor_user_id>" >&2
  echo "  Seeded user A UUID: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" >&2
  echo "  Seeded user B UUID: bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" >&2
  exit 64
fi

if [[ -n "${XDG_RUNTIME_DIR:-}" && -z "${DOCKER_HOST:-}" && -S "${XDG_RUNTIME_DIR}/podman/podman.sock" ]]; then
  export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
fi

SB() { command -v supabase >/dev/null 2>&1 && supabase "$@" || npx supabase "$@"; }

JSON="$(SB status --output json)"
URL="$(printf '%s' "$JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("API_URL",""))')"
SERVICE="$(printf '%s' "$JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("SERVICE_ROLE_KEY",""))')"
if [[ -z "$URL" || -z "$SERVICE" ]]; then
  echo "ERROR: local Supabase not running (./scripts/local_test_env.sh up)" >&2
  exit 1
fi

echo "==> POST ${URL}/functions/v1/send-notification"
curl -sS -X POST "${URL}/functions/v1/send-notification" \
  -H "Authorization: Bearer ${SERVICE}" \
  -H "apikey: ${SERVICE}" \
  -H "Content-Type: application/json" \
  -d "{\"group_id\":\"${GROUP_ID}\",\"actor_user_id\":\"${ACTOR_ID}\",\"action\":\"expense_created\",\"expense_title\":\"Local test\",\"amount_cents\":100,\"currency_code\":\"USD\"}"
echo
