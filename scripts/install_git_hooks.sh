#!/usr/bin/env bash
# Point this clone at the repo-managed hooks under .githooks/
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

git config core.hooksPath .githooks
chmod +x .githooks/pre-push scripts/verify_security.sh scripts/verify_infra.sh scripts/run_release_checks.sh

echo "✅ git hooks installed (core.hooksPath=.githooks)"
echo "   pre-push will run scripts/verify_security.sh on each ref being pushed"
echo "   Bypass only if you must: git push --no-verify"
