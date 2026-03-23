#!/usr/bin/env bash
# Run Supabase CLI commands using Podman's Docker-compatible API.
# Prerequisites: Podman installed; container socket available (see docs/SUPABASE_SETUP.md).
#
# Usage (from repo root):
#   ./scripts/supabase_with_podman.sh start
#   ./scripts/supabase_with_podman.sh db reset
#   ./scripts/supabase_with_podman.sh status
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

if [[ -z "${DOCKER_HOST:-}" ]]; then
  if [[ -n "${XDG_RUNTIME_DIR:-}" && -S "${XDG_RUNTIME_DIR}/podman/podman.sock" ]]; then
    export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
  elif [[ -S "/run/user/$(id -u)/podman/podman.sock" ]]; then
    export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
  fi
fi

if [[ -z "${DOCKER_HOST:-}" ]]; then
  echo "ERROR: DOCKER_HOST is not set and no default Podman socket was found." >&2
  echo "  Rootless Linux: systemctl --user enable --now podman.socket" >&2
  echo "  Then: export DOCKER_HOST=unix://\${XDG_RUNTIME_DIR}/podman/podman.sock" >&2
  echo "  macOS: podman machine start; use socket from: podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}'" >&2
  exit 1
fi

echo "==> Using DOCKER_HOST=$DOCKER_HOST (Podman)"
if command -v supabase >/dev/null 2>&1; then
  exec supabase "$@"
fi
exec npx supabase "$@"
