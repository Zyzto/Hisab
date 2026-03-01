#!/usr/bin/env bash
# Run all tests (unit/widget, then Android + web integration in parallel).
# Wrapper for: dart run tool/run_all_tests.dart
# Options: --skip-unit, --skip-android, --skip-web, --no-avd
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"
exec dart run tool/run_all_tests.dart "$@"
