#!/usr/bin/env bash
# Run online integration tests against a local Supabase instance.
# Thin wrapper for: dart run tool/run_online_tests.dart
#
# Prerequisites:
#   - Docker or Podman (Supabase CLI uses the Docker API; Podman: see docs/SUPABASE_SETUP.md)
#   - Supabase CLI (supabase on PATH, NixOS nixpkgs#supabase-cli, or npx supabase)
#   - For web: Chrome + ChromeDriver (or npx chromedriver)
#
# Usage:
#   ./scripts/run_online_tests.sh            # web (default)
#   ./scripts/run_online_tests.sh android    # android device
#   ./scripts/run_online_tests.sh --platform android
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

exec dart run tool/run_online_tests.dart "$@"
