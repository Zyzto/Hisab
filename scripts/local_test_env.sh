#!/usr/bin/env bash
# Fuller local test environment for Hisab (Podman-first, LAN-ready).
#
# Starts local Supabase via Podman (or Docker), writes dart_defines_local.json
# with a LAN-reachable SUPABASE_URL for physical devices / emulators, and
# optionally loads testing-Firebase FCM secrets for local Edge Functions.
#
# Usage (from repo root):
#   ./scripts/local_test_env.sh up
#   ./scripts/local_test_env.sh status
#   ./scripts/local_test_env.sh test-edge
#   ./scripts/local_test_env.sh down
#
# Env overrides:
#   HISAB_LAN_IP=192.168.1.10   # force LAN IP in defines / SITE_URL
#   HISAB_BIND=loopback         # use 127.0.0.1 instead of LAN (host-only)
#   HISAB_APP_PORT=8080
#   FCM_SERVICE_ACCOUNT_FILE=secrets/fcm-service-account.test.json
#
# See docs/LOCAL_TEST_ENV.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

DEFINES_FILE="${PROJECT_DIR}/dart_defines_local.json"
FUNCTIONS_ENV="${PROJECT_DIR}/functions/.env"
SUPABASE_ENV="${PROJECT_DIR}/supabase/.env"
FB_EMULATOR_PID_FILE="${PROJECT_DIR}/logs/firebase_functions_emulator.pid"
FCM_SERVICE_ACCOUNT_FILE="${FCM_SERVICE_ACCOUNT_FILE:-${PROJECT_DIR}/secrets/fcm-service-account.test.json}"
HISAB_APP_PORT="${HISAB_APP_PORT:-8080}"
HISAB_BIND="${HISAB_BIND:-lan}"

is_nixos() {
  [[ -e /etc/NIXOS ]] || grep -q '^ID=nixos' /etc/os-release 2>/dev/null || \
    grep -q '^ID=nixos' /.host-etc/os-release 2>/dev/null
}

SB() {
  # Always point the CLI at Podman when available (plain `supabase` defaults to
  # unix:///var/run/docker.sock which does not exist on this host).
  detect_podman_socket

  # Prefer a real supabase on PATH (e.g. pkgs.supabase-cli from NixOS).
  if command -v supabase >/dev/null 2>&1; then
    command supabase "$@"
    return
  fi
  # npx's @supabase/cli-linux-x64 is a generic dynamic binary — fails on NixOS
  # without nix-ld. Use nixpkgs supabase-cli instead.
  if is_nixos && command -v nix >/dev/null 2>&1; then
    nix --extra-experimental-features 'nix-command flakes' \
      shell nixpkgs#supabase-cli -c supabase "$@"
    return
  fi
  if command -v npx >/dev/null 2>&1; then
    npx supabase "$@"
    return
  fi
  echo "ERROR: Supabase CLI not found." >&2
  if is_nixos; then
    echo "  On NixOS add: environment.systemPackages = [ pkgs.supabase-cli ];" >&2
    echo "  Or once: nix shell nixpkgs#supabase-cli -c ./scripts/local_test_env.sh up" >&2
  else
    echo "  Install: https://supabase.com/docs/guides/cli" >&2
  fi
  return 1
}

wait_for_api() {
  local i
  echo "==> Waiting for Kong/API on :54321..."
  for i in $(seq 1 60); do
    if curl -sf --connect-timeout 1 --max-time 2 \
      "http://127.0.0.1:54321/auth/v1/health" >/dev/null 2>&1; then
      echo "    API ready (${i}s)"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: API not healthy on http://127.0.0.1:54321 after 60s" >&2
  echo "  Ensure DOCKER_HOST is set to the Podman socket, then: podman ps -a" >&2
  return 1
}

detect_podman_socket() {
  if [[ -n "${DOCKER_HOST:-}" ]]; then
    return
  fi
  # Prefer rootful Podman when the socket is usable — Kong cannot write
  # kong.yml under rootless volumes on this host (Permission denied).
  if [[ -S /run/podman/podman.sock ]] && [[ -w /run/podman/podman.sock || -r /run/podman/podman.sock ]]; then
    export DOCKER_HOST="unix:///run/podman/podman.sock"
    return
  fi
  if [[ -n "${XDG_RUNTIME_DIR:-}" && -S "${XDG_RUNTIME_DIR}/podman/podman.sock" ]]; then
    export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
  elif [[ -S "/run/user/$(id -u)/podman/podman.sock" ]]; then
    export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
  fi
}

ensure_podman_storage_conf() {
  # Rootless Podman without /etc/subuid often fails unpacking image layers.
  # ignore_chown_errors allows pulls to succeed on NixOS-like setups.
  local conf="${HOME}/.config/containers/storage.conf"
  mkdir -p "${HOME}/.config/containers"
  if [[ -f "$conf" ]] && grep -q 'ignore_chown_errors' "$conf"; then
    return 0
  fi
  if [[ ! -f "$conf" ]]; then
    cat >"$conf" <<'EOF'
[storage]
driver = "overlay"

[storage.options]
ignore_chown_errors = "true"
EOF
    echo "==> Wrote ${conf} (ignore_chown_errors=true for rootless Podman)"
    return 0
  fi
  if ! grep -q '\[storage.options\]' "$conf"; then
    printf '\n[storage.options]\nignore_chown_errors = "true"\n' >>"$conf"
  else
    # Insert under [storage.options] if missing
    python3 - "$conf" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
if "ignore_chown_errors" in text:
    raise SystemExit(0)
if "[storage.options]" in text:
    text = text.replace("[storage.options]", '[storage.options]\nignore_chown_errors = "true"', 1)
else:
    text += '\n[storage.options]\nignore_chown_errors = "true"\n'
p.write_text(text)
PY
  fi
  echo "==> Updated ${conf} (ignore_chown_errors=true)"
}

podman_info_ok() {
  # Rootful socket: plain `podman info` still talks to the user engine.
  if [[ -n "${DOCKER_HOST:-}" ]]; then
    if CONTAINER_HOST="${DOCKER_HOST}" podman info >/dev/null 2>&1; then
      return 0
    fi
    if podman --url "${DOCKER_HOST}" info >/dev/null 2>&1; then
      return 0
    fi
  fi
  podman info >/dev/null 2>&1
}

check_container_runtime() {
  detect_podman_socket
  # Prefer Podman (docker on this host is often podman-docker).
  if command -v podman >/dev/null 2>&1 && podman_info_ok; then
    # Rootless-only helper; harmless when using rootful.
    ensure_podman_storage_conf || true
    echo "==> Container runtime: Podman (DOCKER_HOST=${DOCKER_HOST:-unset})"
    if [[ "${DOCKER_HOST:-}" == *"/run/podman/podman.sock" ]]; then
      echo "    Using rootful Podman (recommended for Kong)."
    elif [[ ! -f /etc/subuid || ! -f /etc/subgid ]]; then
      echo "    Note: /etc/subuid+/etc/subgid missing — using ignore_chown_errors."
      echo "    Preferred: rootful socket, or fix subuid (see docs/LOCAL_TEST_ENV.md)."
    fi
    return 0
  fi
  # Socket present + readable is enough for the Supabase CLI even if `podman`
  # CLI quirks fail in restricted shells.
  if [[ -n "${DOCKER_HOST:-}" && "${DOCKER_HOST}" == unix://* ]]; then
    local sock="${DOCKER_HOST#unix://}"
    if [[ -S "$sock" ]]; then
      echo "==> Container runtime: Podman socket (DOCKER_HOST=${DOCKER_HOST})"
      return 0
    fi
  fi
  # Real Docker daemon only (skip if docker is just a Podman alias without a socket).
  if [[ -S /var/run/docker.sock ]] && command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    unset DOCKER_HOST || true
    echo "==> Container runtime: Docker"
    return 0
  fi
  echo "ERROR: No container engine reachable (podman info failed; no Docker daemon socket)." >&2
  echo "  Rootful: sudo systemctl enable --now podman.socket" >&2
  echo "  export DOCKER_HOST=unix:///run/podman/podman.sock" >&2
  echo "  See docs/LOCAL_TEST_ENV.md" >&2
  return 1
}

check_supabase_cli() {
  if command -v supabase >/dev/null 2>&1 || command -v npx >/dev/null 2>&1; then
    return 0
  fi
  echo "ERROR: Supabase CLI not found. Install: https://supabase.com/docs/guides/cli" >&2
  return 1
}

detect_lan_ip() {
  if [[ -n "${HISAB_LAN_IP:-}" ]]; then
    printf '%s' "$HISAB_LAN_IP"
    return
  fi
  local ip=""
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}' || true)"
  fi
  if [[ -z "$ip" ]] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  fi
  if [[ -z "$ip" || "$ip" == "127.0.0.1" ]]; then
    ip="127.0.0.1"
  fi
  printf '%s' "$ip"
}

resolve_public_host() {
  if [[ "${HISAB_BIND}" == "loopback" ]]; then
    printf '%s' "127.0.0.1"
  else
    detect_lan_ip
  fi
}

rewrite_url_host() {
  local url="$1"
  local host="$2"
  python3 -c 'import sys; from urllib.parse import urlparse, urlunparse
u=urlparse(sys.argv[1]); host=sys.argv[2]
port=u.port
netloc=f"{host}:{port}" if port else host
print(urlunparse((u.scheme, netloc, u.path, u.params, u.query, u.fragment)))' "$url" "$host"
}

supabase_status_json() {
  SB status --output json 2>/dev/null
}

status_field() {
  local json="$1"
  local key="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r --arg k "$key" '.[$k] // empty'
    return
  fi
  printf '%s' "$json" | python3 -c \
    'import json,sys; data=json.load(sys.stdin); v=data.get(sys.argv[1]); print(v if v is not None else "")' \
    "$key"
}

existing_define() {
  local key="$1"
  if [[ ! -f "$DEFINES_FILE" ]]; then
    printf ''
    return
  fi
  python3 -c 'import json,sys
p=sys.argv[1]; k=sys.argv[2]
try:
  d=json.load(open(p))
  print(d.get(k) or "")
except Exception:
  print("")' "$DEFINES_FILE" "$key"
}

write_dart_defines() {
  local json url anon host public_url site invite
  json="$(supabase_status_json)" || {
    echo "ERROR: supabase status failed (is the stack up?)" >&2
    return 1
  }
  url="$(status_field "$json" "API_URL")"
  anon="$(status_field "$json" "ANON_KEY")"
  if [[ -z "$url" || -z "$anon" || "$url" == "null" || "$anon" == "null" ]]; then
    echo "ERROR: Could not read API_URL / ANON_KEY from supabase status" >&2
    return 1
  fi

  host="$(resolve_public_host)"
  public_url="$(rewrite_url_host "$url" "$host")"
  site="${SITE_URL:-http://${host}:${HISAB_APP_PORT}}"
  invite="${INVITE_BASE_URL:-$site}"
  SITE_URL="$site"
  INVITE_BASE_URL="$invite"

  local vapid api_key auth_domain project_id storage_bucket sender_id app_id
  vapid="$(existing_define FCM_VAPID_KEY)"
  api_key="$(existing_define FIREBASE_API_KEY)"
  auth_domain="$(existing_define FIREBASE_AUTH_DOMAIN)"
  project_id="$(existing_define FIREBASE_PROJECT_ID)"
  storage_bucket="$(existing_define FIREBASE_STORAGE_BUCKET)"
  sender_id="$(existing_define FIREBASE_MESSAGING_SENDER_ID)"
  app_id="$(existing_define FIREBASE_APP_ID)"

  python3 - "$DEFINES_FILE" "$public_url" "$anon" "$invite" "$site" \
    "$vapid" "$api_key" "$auth_domain" "$project_id" "$storage_bucket" "$sender_id" "$app_id" <<'PY'
import json, sys
path, url, anon, invite, site, vapid, api_key, auth_domain, project_id, bucket, sender, app_id = sys.argv[1:]
data = {
  "SUPABASE_URL": url,
  "SUPABASE_ANON_KEY": anon,
  "INVITE_BASE_URL": invite,
  "SITE_URL": site,
  "FCM_VAPID_KEY": vapid,
  "FIREBASE_API_KEY": api_key,
  "FIREBASE_AUTH_DOMAIN": auth_domain,
  "FIREBASE_PROJECT_ID": project_id,
  "FIREBASE_STORAGE_BUCKET": bucket,
  "FIREBASE_MESSAGING_SENDER_ID": sender,
  "FIREBASE_APP_ID": app_id,
}
with open(path, "w", encoding="utf-8") as f:
  json.dump(data, f, indent=2)
  f.write("\n")
PY

  echo "==> Wrote ${DEFINES_FILE}"
  echo "    SUPABASE_URL=${public_url}"
  echo "    SITE_URL=${site}"
  if [[ -z "$project_id" ]]; then
    echo "    Firebase keys: empty — add test-project values (see docs/LOCAL_TEST_ENV.md#testing-firebase-fcm)"
  else
    echo "    Firebase keys: preserved (FIREBASE_PROJECT_ID=${project_id})"
  fi
}

write_functions_env() {
  local json url host public_url
  json="$(supabase_status_json)" || return 1
  url="$(status_field "$json" "API_URL")"
  if [[ -z "$url" || "$url" == "null" ]]; then
    echo "ERROR: Could not read API_URL for functions/.env" >&2
    return 1
  fi
  host="$(resolve_public_host)"
  public_url="$(rewrite_url_host "$url" "$host")"
  SITE_URL="${SITE_URL:-http://${host}:${HISAB_APP_PORT}}"
  cat >"$FUNCTIONS_ENV" <<EOF
# Generated by scripts/local_test_env.sh — do not commit.
SUPABASE_URL=${public_url}
SITE_URL=${SITE_URL}
EOF
  echo "==> Wrote ${FUNCTIONS_ENV}"
}

write_supabase_env() {
  local host site
  host="$(resolve_public_host)"
  site="${SITE_URL:-http://${host}:${HISAB_APP_PORT}}"
  SITE_URL="$site"

  {
    echo "# Generated by scripts/local_test_env.sh — do not commit."
    echo "SITE_URL=${site}"
  } >"$SUPABASE_ENV"

  if [[ -f "$FCM_SERVICE_ACCOUNT_FILE" ]]; then
    local project_id key_json
    project_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("project_id",""))' "$FCM_SERVICE_ACCOUNT_FILE")"
    key_json="$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' "$FCM_SERVICE_ACCOUNT_FILE")"
    if [[ -n "$project_id" && -n "$key_json" ]]; then
      {
        echo "FCM_PROJECT_ID=${project_id}"
        # Single-line JSON for env parsing
        printf 'FCM_SERVICE_ACCOUNT_KEY=%s\n' "$key_json"
      } >>"$SUPABASE_ENV"
      echo "==> Wrote ${SUPABASE_ENV} (SITE_URL + FCM from ${FCM_SERVICE_ACCOUNT_FILE})"
      echo "    FCM_PROJECT_ID=${project_id} — send-notification will use real FCM (not dry-run)"
      return
    fi
  fi

  echo "==> Wrote ${SUPABASE_ENV} (SITE_URL only; FCM dry-run until secrets file exists)"
  echo "    Place service account at: ${FCM_SERVICE_ACCOUNT_FILE}"
  echo "    Guide: docs/LOCAL_TEST_ENV.md#testing-firebase-fcm"
}

update_auth_redirects() {
  local host site config
  host="$(resolve_public_host)"
  site="http://${host}:${HISAB_APP_PORT}"
  config="${PROJECT_DIR}/supabase/config.toml"
  # Keep localhost + deep link; ensure LAN site URL is listed for auth redirects.
  if grep -q "additional_redirect_urls" "$config"; then
    python3 - "$config" "$site" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
site = sys.argv[2]
text = path.read_text()
deep = "io.supabase.hisab://callback"
wanted = [
  "http://localhost:8080",
  "http://127.0.0.1:8080",
  site,
  deep,
]
# Deduplicate while preserving order
seen = set()
urls = []
for u in wanted:
  if u not in seen:
    seen.add(u)
    urls.append(u)
line = "additional_redirect_urls = [" + ", ".join(f'"{u}"' for u in urls) + "]"
new, n = re.subn(
  r'^additional_redirect_urls\s*=\s*\[.*?\]\s*$',
  line,
  text,
  count=1,
  flags=re.M,
)
if n:
  path.write_text(new)
  print(f"==> Updated auth additional_redirect_urls (+ {site})")
else:
  print("WARNING: could not patch additional_redirect_urls in config.toml", file=sys.stderr)
PY
  fi
}

cmd_up() {
  check_container_runtime
  check_supabase_cli
  bash "${SCRIPT_DIR}/verify_supabase_config_as_code.sh"

  local host
  host="$(resolve_public_host)"
  SITE_URL="${SITE_URL:-http://${host}:${HISAB_APP_PORT}}"
  INVITE_BASE_URL="${INVITE_BASE_URL:-$SITE_URL}"

  update_auth_redirects
  write_supabase_env

  echo "==> Starting local Supabase (Podman/Docker)..."
  echo "    DOCKER_HOST=${DOCKER_HOST:-unset}"
  # Analytics/vector/syslog often break rootless Podman; config.toml has analytics off.
  # Volume-prune "all" filter warnings from older Podman are usually non-fatal.
  #
  # If a previous run left DB up but Kong dead, plain `supabase start` is a no-op
  # ("already running") and :54321 never comes back — force a clean restart.
  local status_out=""
  status_out="$(SB status 2>&1 || true)"
  if printf '%s' "$status_out" | grep -q 'supabase_kong_hisab' \
    && printf '%s' "$status_out" | grep -Eqi 'Stopped services:.*kong|not running|stopped'; then
    echo "==> Kong is stopped while stack looks running — forcing restart..."
    SB stop --no-backup || true
  elif ! curl -sf --connect-timeout 1 --max-time 2 \
    "http://127.0.0.1:54321/auth/v1/health" >/dev/null 2>&1; then
    if printf '%s' "$status_out" | grep -qi 'already running\|is running'; then
      echo "==> API down but CLI reports running — forcing restart..."
      SB stop --no-backup || true
    fi
  fi

  # Valid exclude names (CLI 2.100): no "analytics" — use logflare/vector only.
  if ! SB start -x logflare,vector; then
    echo "==> Start reported errors; retrying with --ignore-health-check..."
    SB start -x logflare,vector --ignore-health-check
  fi
  # If Kong still did not come up, one more hard recycle.
  if ! curl -sf --connect-timeout 1 --max-time 2 \
    "http://127.0.0.1:54321/auth/v1/health" >/dev/null 2>&1; then
    echo "==> API still down; recycling containers..."
    SB stop --no-backup || true
    SB start -x logflare,vector --ignore-health-check
  fi
  wait_for_api

  echo "==> Resetting database (migrations + seed)..."
  # db reset restarts containers; Kong can RST briefly — retry once after wait.
  if ! SB db reset; then
    echo "==> db reset failed (often a Kong restart race); waiting and retrying..."
    wait_for_api
    SB db reset
  fi
  wait_for_api

  write_dart_defines
  write_functions_env

  echo ""
  echo "Local test env is up (bind=${HISAB_BIND}, host=${host})."
  echo "  Physical device / emulator:"
  echo "    flutter run --dart-define-from-file=dart_defines_local.json -d <device>"
  echo "  Web on this machine:"
  echo "    flutter run -d chrome --dart-define-from-file=dart_defines_local.json --web-port=${HISAB_APP_PORT}"
  echo "  VS Code: Hisab (Local Online) / Hisab (Chrome Local Online) / Hisab (Local Online, Android)"
  echo "  Studio:   http://127.0.0.1:54323"
  echo "  Inbucket: http://127.0.0.1:54324"
  echo "  Seeded:   test-a@hisab.test / TestPass123!"
  echo ""
  echo "  Firewall: allow TCP ${HISAB_APP_PORT} and 54321 from your LAN."
  echo "  FCM setup: docs/LOCAL_TEST_ENV.md#testing-firebase-fcm"
  echo "  After adding FCM secrets file: ./scripts/local_test_env.sh reload-secrets"
}

cmd_down() {
  detect_podman_socket
  if [[ -f "$FB_EMULATOR_PID_FILE" ]]; then
    local pid
    pid="$(cat "$FB_EMULATOR_PID_FILE" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "==> Stopping Firebase Functions emulator (pid=$pid)..."
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$FB_EMULATOR_PID_FILE"
  fi
  echo "==> Stopping local Supabase..."
  SB stop || true
  echo "Local test env stopped."
}

cmd_status() {
  detect_podman_socket
  local host
  host="$(resolve_public_host)"
  echo "==> Public host (${HISAB_BIND}): ${host}"
  echo "==> Supabase status"
  if ! SB status; then
    echo "(Supabase not running)"
  fi
  echo ""
  if [[ -f "$DEFINES_FILE" ]]; then
    echo "dart_defines_local.json: present"
    python3 -c 'import json; d=json.load(open("dart_defines_local.json")); print("  SUPABASE_URL=", d.get("SUPABASE_URL")); print("  SITE_URL=", d.get("SITE_URL")); print("  FIREBASE_PROJECT_ID=", d.get("FIREBASE_PROJECT_ID") or "(empty)")'
  else
    echo "dart_defines_local.json: missing (run: ./scripts/local_test_env.sh up)"
  fi
  if [[ -f "$FCM_SERVICE_ACCOUNT_FILE" ]]; then
    echo "FCM service account: present (${FCM_SERVICE_ACCOUNT_FILE})"
  else
    echo "FCM service account: missing (${FCM_SERVICE_ACCOUNT_FILE})"
  fi
  if [[ -f "$SUPABASE_ENV" ]]; then
    if grep -q '^FCM_PROJECT_ID=' "$SUPABASE_ENV"; then
      echo "supabase/.env: SITE_URL + FCM secrets"
    else
      echo "supabase/.env: SITE_URL only (FCM dry-run)"
    fi
  else
    echo "supabase/.env: missing"
  fi
  echo ""
  echo "Ports: API 54321 | DB 54322 | Studio 54323 | Inbucket 54324 | App ${HISAB_APP_PORT}"
}

cmd_reset() {
  check_container_runtime
  check_supabase_cli
  echo "==> Resetting database (migrations + seed)..."
  SB db reset
  write_supabase_env
  write_dart_defines
  write_functions_env
  echo "Database reset complete."
}

cmd_reload_secrets() {
  check_container_runtime
  check_supabase_cli
  if ! supabase_status_json >/dev/null 2>&1; then
    echo "ERROR: Supabase is not running. Run: ./scripts/local_test_env.sh up" >&2
    exit 1
  fi
  write_supabase_env
  write_dart_defines
  write_functions_env
  echo "==> Restarting Supabase so Edge picks up secrets..."
  SB stop || true
  SB start
  echo "Secrets reloaded."
}

cmd_serve_functions() {
  check_container_runtime
  if ! supabase_status_json >/dev/null 2>&1; then
    echo "ERROR: Supabase is not running. Run: ./scripts/local_test_env.sh up" >&2
    exit 1
  fi
  write_functions_env
  mkdir -p "${PROJECT_DIR}/logs"
  if [[ ! -d "${PROJECT_DIR}/functions/node_modules" ]]; then
    echo "==> npm install in functions/..."
    (cd "${PROJECT_DIR}/functions" && npm install)
  fi
  echo "==> Starting Firebase Functions emulator (port 5001, UI 4000)..."
  echo "    Ctrl+C to stop (or ./scripts/local_test_env.sh down)."
  (cd "${PROJECT_DIR}/functions" && npm run serve)
}

cmd_test() {
  echo "==> Unit + widget tests"
  flutter test
  echo "==> Local web integration"
  ./scripts/run_web_integration_tests.sh
  if ! supabase_status_json >/dev/null 2>&1; then
    echo "==> Starting Supabase for edge smoke..."
    check_container_runtime
    check_supabase_cli
    write_supabase_env
    SB start
    SB db reset
    write_dart_defines
    write_functions_env
  fi
  echo "==> Edge HTTP smoke"
  cmd_test_edge
  echo "==> Online integration (local Supabase)"
  ./scripts/run_online_tests.sh
}

cmd_test_edge() {
  check_container_runtime
  check_supabase_cli
  local json url anon service host site
  if ! json="$(supabase_status_json)"; then
    echo "ERROR: Supabase is not running. Run: ./scripts/local_test_env.sh up" >&2
    exit 1
  fi
  url="$(status_field "$json" "API_URL")"
  anon="$(status_field "$json" "ANON_KEY")"
  service="$(status_field "$json" "SERVICE_ROLE_KEY")"
  host="$(resolve_public_host)"
  site="${SITE_URL:-http://${host}:${HISAB_APP_PORT}}"
  if [[ -z "$url" || -z "$anon" || -z "$service" ]]; then
    echo "ERROR: Could not read API_URL / ANON_KEY / SERVICE_ROLE_KEY" >&2
    exit 1
  fi
  echo "==> Edge Function HTTP smoke tests against ${url}"
  flutter test test/edge/ \
    --dart-define="SUPABASE_URL=${url}" \
    --dart-define="SUPABASE_ANON_KEY=${anon}" \
    --dart-define="SUPABASE_SERVICE_ROLE_KEY=${service}" \
    --dart-define="SITE_URL=${site}"
}

usage() {
  cat <<EOF
Usage: ./scripts/local_test_env.sh <command>

Commands:
  up               Start Supabase (Podman-first), db reset, write LAN dart_defines + envs
  down             Stop Supabase and Firebase Functions emulator (if tracked)
  status           Show stack / LAN host / defines / FCM secret status
  reset            db reset + regenerate defines
  reload-secrets   Rewrite supabase/.env from FCM file and restart Supabase
  serve-functions  Start Firebase Functions emulator (requires stack up)
  test             Unit/widget + local web integration + online + edge smoke
  test-edge        Edge Function HTTP smoke tests only

Env:
  HISAB_LAN_IP / HISAB_BIND=lan|loopback / HISAB_APP_PORT
  FCM_SERVICE_ACCOUNT_FILE (default: secrets/fcm-service-account.test.json)

Docs: docs/LOCAL_TEST_ENV.md
EOF
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    up) cmd_up ;;
    down) cmd_down ;;
    status) cmd_status ;;
    reset) cmd_reset ;;
    reload-secrets) cmd_reload_secrets ;;
    serve-functions) cmd_serve_functions ;;
    test) cmd_test ;;
    test-edge) cmd_test_edge ;;
    -h|--help|help|"") usage ;;
    *)
      echo "ERROR: Unknown command: $cmd" >&2
      usage >&2
      exit 64
      ;;
  esac
}

main "$@"
