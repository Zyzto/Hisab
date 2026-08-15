#!/usr/bin/env bash
# Fail if the public tree has grown a dependency on a backend SDK.
#
# The open-core split only holds if this repo builds standalone. Cal.com's
# split failed exactly here: hundreds of imports crossed from the open tree
# into the licensed one, so the "open source" build no longer stood alone. The
# imports are cheap to add and invisible until someone tries a clean clone, so
# they are checked rather than trusted.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

status=0

fail() {
  echo "❌ $1" >&2
  status=1
}

if grep -rn --include='*.dart' -E "^\s*import\s+'package:supabase" lib test packages; then
  fail "lib/, test/ or packages/ imports a Supabase SDK; the app must go through package:hisab_backend"
fi

if grep -nE '^\s*supabase(_flutter)?\s*:' pubspec.yaml; then
  fail "pubspec.yaml declares a Supabase dependency"
fi

# The stub is what makes the public build offline. A path pointing outside the
# repo means someone wired the private package in and it would not resolve for
# anyone else.
if ! grep -q 'path: packages/hisab_cloud' pubspec.yaml; then
  fail "pubspec.yaml no longer resolves hisab_cloud to the in-repo stub"
fi

if git ls-files --error-unmatch android/app/src/cloud/google-services.json >/dev/null 2>&1; then
  fail "android/app/src/cloud/google-services.json is tracked; it must stay gitignored"
fi

if [[ $status -eq 0 ]]; then
  echo "✅ Public tree is standalone"
fi
exit $status
