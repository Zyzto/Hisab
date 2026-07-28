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
  # Prefer rootful — Kong often cannot write kong.yml under rootless volumes.
  if [[ -S /run/podman/podman.sock ]] && [[ -r /run/podman/podman.sock || -w /run/podman/podman.sock ]]; then
    export DOCKER_HOST="unix:///run/podman/podman.sock"
  elif [[ -n "${XDG_RUNTIME_DIR:-}" && -S "${XDG_RUNTIME_DIR}/podman/podman.sock" ]]; then
    export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
  elif [[ -S "/run/user/$(id -u)/podman/podman.sock" ]]; then
    export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
  fi
fi

if [[ -z "${DOCKER_HOST:-}" ]]; then
  echo "ERROR: DOCKER_HOST is not set and no default Podman socket was found." >&2
  echo "  Rootful (recommended): sudo systemctl enable --now podman.socket" >&2
  echo "  Then: export DOCKER_HOST=unix:///run/podman/podman.sock" >&2
  echo "  Rootless: systemctl --user enable --now podman.socket" >&2
  echo "  Then: export DOCKER_HOST=unix://\${XDG_RUNTIME_DIR}/podman/podman.sock" >&2
  echo "  macOS: podman machine start; use socket from: podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}'" >&2
  exit 1
fi

echo "==> Using DOCKER_HOST=$DOCKER_HOST (Podman)"
if command -v supabase >/dev/null 2>&1; then
  exec supabase "$@"
fi
# npx binary is dynamically linked and fails on NixOS without nix-ld.
if [[ -e /etc/NIXOS ]] || grep -q '^ID=nixos' /etc/os-release 2>/dev/null; then
  if command -v nix >/dev/null 2>&1; then
    exec nix --extra-experimental-features 'nix-command flakes' \
      shell nixpkgs#supabase-cli -c supabase "$@"
  fi
  echo "ERROR: Install pkgs.supabase-cli on NixOS (npx supabase will not run)." >&2
  exit 1
fi
exec npx supabase "$@"
