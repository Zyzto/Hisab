#!/usr/bin/env bash
# Cursor beforeShellExecution: block git push when sensitive info is present.
# Reads hook JSON from stdin; writes permission JSON to stdout.
set -euo pipefail

input=$(cat || true)

# Prefer python3 for JSON; fall back to allowing if parse fails open only when
# the command clearly is not a push.
command=""
if command -v python3 >/dev/null 2>&1; then
  command=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("command",""))' 2>/dev/null || true)
else
  command=$(printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# Only gate push-like commands (not e.g. git push --help via wrong match — still ok)
if ! printf '%s' "$command" | grep -Eq '(^|[[:space:];|&])git[[:space:]]+push([[:space:]]|$)'; then
  printf '%s\n' '{"permission":"allow"}'
  exit 0
fi

# Honor explicit bypass used by humans who know what they're doing.
if printf '%s' "$command" | grep -Eq -- '--no-verify|-n([[:space:]]|$)'; then
  printf '%s\n' '{"permission":"allow","agent_message":"git push --no-verify: skipping secret scan (explicit bypass)."}'
  exit 0
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT" || ! -f "$ROOT/scripts/verify_security.sh" ]]; then
  printf '%s\n' '{"permission":"allow"}'
  exit 0
fi

# Scan HEAD (what a typical push sends). Full per-ref scan still runs in .githooks/pre-push.
if ! HISAB_SCAN_TREE="$(git -C "$ROOT" rev-parse HEAD)" bash "$ROOT/scripts/verify_security.sh" >/tmp/hisab-push-secret-scan.log 2>&1; then
  # Escape log for JSON (keep it short)
  detail=$(tail -n 20 /tmp/hisab-push-secret-scan.log | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo '""')
  cat <<EOF
{"permission":"deny","user_message":"Push blocked: sensitive information detected. See SECURITY.md and run: bash ./scripts/verify_security.sh","agent_message":"Secret scan failed before git push. Output: ${detail}"}
EOF
  exit 0
fi

printf '%s\n' '{"permission":"allow"}'
exit 0
