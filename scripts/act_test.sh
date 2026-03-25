#!/usr/bin/env bash
# Run a GitHub Actions workflow job locally via nektos/act + Podman.
#
# Prerequisites (one-time setup):
#   1. Install act:
#        curl -sSL https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz \
#          | tar xz -C ~/.local/bin act
#   2. Enable the Podman socket (Docker API compat):
#        systemctl --user enable --now podman.socket
#
# Usage:
#   bash scripts/act_test.sh                  # runs the "test" job (default)
#   bash scripts/act_test.sh --job test       # explicit job name
#   bash scripts/act_test.sh --job test-online
#   bash scripts/act_test.sh --privileged     # pass --privileged to container
#   bash scripts/act_test.sh -- --verbose     # extra flags forwarded to act
#
# The first run pulls a ~12 GB Ubuntu runner image; subsequent runs use cache.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ──────────────────────────────────────────────
JOB="test"
PRIVILEGED=""
ACT_EXTRA_ARGS=()
RUNNER_IMAGE="catthehacker/ubuntu:full-latest"

# ── Parse arguments ───────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --job)
      JOB="$2"; shift 2 ;;
    --privileged)
      PRIVILEGED="--container-options --privileged"; shift ;;
    --image)
      RUNNER_IMAGE="$2"; shift 2 ;;
    --)
      shift; ACT_EXTRA_ARGS+=("$@"); break ;;
    *)
      ACT_EXTRA_ARGS+=("$1"); shift ;;
  esac
done

# ── Prerequisite checks ──────────────────────────────────
check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: '$1' not found."
    echo "$2"
    exit 1
  fi
}

check_cmd act \
  "Install: curl -sSL https://github.com/nektos/act/releases/latest/download/act_Linux_x86_64.tar.gz | tar xz -C ~/.local/bin act"

check_cmd podman \
  "Install podman via your package manager (e.g. sudo pacman -S podman)."

# ── Podman socket ─────────────────────────────────────────
PODMAN_SOCK="/run/user/$(id -u)/podman/podman.sock"

if [[ ! -S "$PODMAN_SOCK" ]]; then
  echo "Podman socket not found at $PODMAN_SOCK"
  echo "Starting it now..."
  systemctl --user start podman.socket
  sleep 1
  if [[ ! -S "$PODMAN_SOCK" ]]; then
    echo "ERROR: Could not start Podman socket."
    echo "Run: systemctl --user enable --now podman.socket"
    exit 1
  fi
fi

export DOCKER_HOST="unix://$PODMAN_SOCK"

# ── Run ───────────────────────────────────────────────────
echo "╭──────────────────────────────────────────────╮"
echo "│  act + Podman  │  job: $JOB"
echo "│  image: $RUNNER_IMAGE"
echo "╰──────────────────────────────────────────────╯"

cd "$PROJECT_DIR"

# shellcheck disable=SC2086
act push \
  --job "$JOB" \
  -P "ubuntu-latest=$RUNNER_IMAGE" \
  --container-daemon-socket "$PODMAN_SOCK" \
  $PRIVILEGED \
  "${ACT_EXTRA_ARGS[@]+"${ACT_EXTRA_ARGS[@]}"}"
