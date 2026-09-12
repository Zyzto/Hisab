#!/usr/bin/env bash
# Static checks for secrets accidentally entering the public repository.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "❌ $1" >&2
  exit 1
}

SCAN_TREE="${HISAB_SCAN_TREE:-}"
if [[ -n "${SCAN_TREE}" ]]; then
  tracked=$(git ls-tree -r --name-only "${SCAN_TREE}")
else
  tracked=$(git ls-files)
fi

echo "==> Security check (static)${SCAN_TREE:+ — tree ${SCAN_TREE}}"

for path in \
  "android/key.properties" \
  "signing_keys.json" \
  "secrets/production.env" \
  "secrets/release.env"; do
  if printf '%s\n' "${tracked}" | grep -Fx "$path" >/dev/null; then
    fail "Tracked secret path found: $path"
  fi
done

if printf '%s\n' "${tracked}" | grep -E '(^|/)(credentials|private|[^/]+\.(jks|keystore|pem|p12))$' >/dev/null; then
  fail "Tracked signing or credential file found"
fi

text_paths=$(printf '%s\n' "${tracked}" | grep -E '\.(dart|ts|js|json|yml|yaml|toml|env|html|sh|properties|plist|gradle|kts|md|txt|xml)$' || true)

grep_tree() {
  local pattern="$1"
  [[ -n "${text_paths}" ]] || return 1
  if [[ -n "${SCAN_TREE}" ]]; then
    while IFS= read -r file; do
      git grep -nE -- "$pattern" "${SCAN_TREE}" -- "$file" 2>/dev/null || true
    done <<< "${text_paths}"
  else
    while IFS= read -r file; do
      [[ -f "${file}" ]] || continue
      grep -nE -- "$pattern" "$file" 2>/dev/null || true
    done <<< "${text_paths}"
  fi
}

if matches=$(grep_tree 'BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY'); then
  [[ -z "${matches}" ]] || { echo "${matches}" >&2; fail "Private key material found"; }
fi

if matches=$(grep_tree 'AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|sk_live_[A-Za-z0-9]{20,}'); then
  [[ -z "${matches}" ]] || { echo "${matches}" >&2; fail "Credential token found"; }
fi

if matches=$(grep_tree '(postgres|postgresql|mysql|mongodb(\+srv)?)://[^[:space:]/'\''"]+:[^[:space:]/'\''"]+@'); then
  filtered=$(printf '%s\n' "${matches}" | grep -viE 'user:pass@|USER:PASSWORD|example|placeholder|your[_-]?password|PASSWORD@|\$\{PASSWORD\}' || true)
  [[ -z "${filtered}" ]] || { echo "${filtered}" >&2; fail "Database credential URL found"; }
fi

echo "✅ Security check passed"
