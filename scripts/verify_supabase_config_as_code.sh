#!/usr/bin/env bash
# Verifies Supabase "Config as Code" repo invariants.
# Safe to run locally and in CI.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "❌ $1" >&2
  exit 1
}

echo "==> Verifying Supabase config-as-code files"

[[ -f "supabase/config.toml" ]] || fail "Missing supabase/config.toml"
[[ -f "supabase/seed.sql" ]] || fail "Missing supabase/seed.sql"

shopt -s nullglob
migrations=(supabase/migrations/*.sql)
shopt -u nullglob
(( ${#migrations[@]} > 0 )) || fail "No SQL files found in supabase/migrations/"

echo "==> Checking migration filename format and ordering"
prev=""
for file in "${migrations[@]}"; do
  base="$(basename "$file")"
  if [[ ! "$base" =~ ^[0-9]{14}_[a-z0-9_]+\.sql$ ]]; then
    fail "Invalid migration filename: $base (expected 14-digit timestamp + snake_case name)"
  fi

  if [[ -n "$prev" && "$base" < "$prev" ]]; then
    fail "Migrations are not lexicographically ordered: $prev then $base"
  fi
  prev="$base"
done

echo "==> Verifying key Supabase files are tracked by git"
for tracked in supabase/config.toml supabase/seed.sql; do
  git ls-files --error-unmatch "$tracked" >/dev/null 2>&1 || fail "$tracked is not tracked in git"
done

for file in "${migrations[@]}"; do
  git ls-files --error-unmatch "$file" >/dev/null 2>&1 || fail "$file is not tracked in git"
done

echo "✅ Supabase config-as-code checks passed"
