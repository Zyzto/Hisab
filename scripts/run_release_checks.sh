#!/usr/bin/env bash
# Run static security + client infra checks (CI + local pre-release).
# Backend checks live in the private cloud repo's copy of these scripts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash ./scripts/verify_security.sh
bash ./scripts/verify_infra.sh

echo "✅ All static release checks passed"
