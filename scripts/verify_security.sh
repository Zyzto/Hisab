#!/usr/bin/env bash
# Static security checks for a public repo (see SECURITY.md).
# Safe to run locally and in CI — no network, no secrets required.
#
# Optional:
#   HISAB_SCAN_TREE=<git-sha>  Scan that commit tree (used by pre-push) instead of the index.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "❌ $1" >&2
  exit 1
}

warn() {
  echo "⚠️  $1" >&2
}

SCAN_TREE="${HISAB_SCAN_TREE:-}"

list_tracked() {
  if [[ -n "$SCAN_TREE" ]]; then
    git ls-tree -r --name-only "$SCAN_TREE"
  else
    git ls-files
  fi
}

is_tracked() {
  local path="$1"
  if [[ -n "$SCAN_TREE" ]]; then
    git cat-file -e "${SCAN_TREE}:${path}" 2>/dev/null
  else
    git ls-files --error-unmatch "$path" >/dev/null 2>&1
  fi
}

# grep tracked files; prints matches to stdout. Returns 0 if any match.
grep_tracked() {
  local pattern="$1"
  shift
  local paths
  paths=$(list_tracked | grep -E '\.(dart|ts|js|json|yml|yaml|toml|env|html|sh|properties|plist|gradle|kts|md|txt|xml|csv)$' || true)
  [[ -n "$paths" ]] || return 1
  if [[ -n "$SCAN_TREE" ]]; then
    # git grep against the commit tree (what will be pushed)
    echo "$paths" | tr '\n' '\0' | xargs -0 -r git grep -nE -e "$pattern" "$SCAN_TREE" -- 2>/dev/null || return 1
  else
    echo "$paths" | tr '\n' '\0' | xargs -0 -r grep -nE -- "$pattern" 2>/dev/null || return 1
  fi
}

echo "==> Security check (static)${SCAN_TREE:+ — tree $SCAN_TREE}"

# ── Paths that must never be tracked ──────────────────────────────────────────
must_not_track=(
  "dart_defines_online.json"
  "dart_defines_local.json"
  "lib/core/constants/app_secrets.dart"
  "android/app/google-services.json"
  "ios/Runner/GoogleService-Info.plist"
  "android/key.properties"
  "supabase/.env"
  "functions/.env"
  "signing_keys.json"
)

for path in "${must_not_track[@]}"; do
  if is_tracked "$path"; then
    fail "Tracked secret path (must be gitignored): $path"
  fi
done

tracked=$(list_tracked)

if echo "$tracked" | grep -E '\.(jks|keystore)$' >/dev/null; then
  fail "Tracked keystore file(s) found"
fi
if echo "$tracked" | grep -Ei 'fcm-service-account|serviceAccount|firebase-adminsdk|client_secret|credentials\.json$' >/dev/null; then
  fail "Tracked credential-like filename(s) found"
fi
if echo "$tracked" | grep -E '^secrets/' | grep -vE 'secrets/(\.gitkeep|README\.md)$' >/dev/null; then
  fail "Unexpected tracked file under secrets/ (only README.md and .gitkeep allowed)"
fi
# Allow *.env.example / *.env.sample templates only.
if echo "$tracked" | grep -E '(^|/)\.env($|\.[^/]+)$' | grep -vE '\.env\.(example|sample)$' >/dev/null; then
  fail "Tracked .env file(s) found (templates *.env.example / *.env.sample are OK)"
fi

# ── High-signal secret patterns ───────────────────────────────────────────────
# Private key PEM blocks
if matches=$(grep_tracked 'BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY'); then
  echo "$matches" >&2
  fail "Private key PEM material found in tracked files"
fi

# Google / Firebase API keys
if matches=$(grep_tracked 'AIza[0-9A-Za-z_-]{30,}'); then
  # Allow docs that show truncated examples
  real=$(echo "$matches" | grep -vE 'AIza\.\.\.|YOUR_|example|placeholder|__FIREBASE_' || true)
  if [[ -n "$real" ]]; then
    echo "$real" >&2
    fail "Google/Firebase API key literal found in tracked files"
  fi
fi

# AWS access key IDs
if matches=$(grep_tracked 'AKIA[0-9A-Z]{16}'); then
  echo "$matches" >&2
  fail "AWS access key ID found in tracked files"
fi

# GitHub tokens
if matches=$(grep_tracked '(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|gho_[A-Za-z0-9]{20,})'); then
  echo "$matches" >&2
  fail "GitHub token found in tracked files"
fi

# Slack tokens
if matches=$(grep_tracked 'xox[baprs]-[A-Za-z0-9-]{10,}'); then
  echo "$matches" >&2
  fail "Slack token found in tracked files"
fi

# Stripe live secret keys
if matches=$(grep_tracked 'sk_live_[A-Za-z0-9]{20,}'); then
  echo "$matches" >&2
  fail "Stripe live secret key found in tracked files"
fi

# Supabase JWT-shaped tokens (anon/service_role typically start with eyJ)
if matches=$(grep_tracked 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}'); then
  filtered=$(echo "$matches" | grep -viE 'example|placeholder|YOUR_|xxxx|\.\.\.' || true)
  real=$(echo "$filtered" | grep -E 'eyJ[A-Za-z0-9_-]{40,}\.' || true)
  if [[ -n "$real" ]]; then
    echo "$real" >&2
    fail "JWT-like token found in tracked files"
  fi
fi

# Hardcoded service_role assignment
if matches=$(grep_tracked '(service_role[_[:alnum:]]*\s*[:=]\s*['\''"]eyJ|SUPABASE_SERVICE_ROLE_KEY\s*[:=]\s*['\''"][^E])'); then
  echo "$matches" >&2
  fail "Hardcoded service_role / SUPABASE_SERVICE_ROLE_KEY value found"
fi

# Connection strings with embedded passwords (skip docs placeholders)
if matches=$(grep_tracked '(postgres|postgresql|mysql|mongodb(\+srv)?)://[^[:space:]/'\'']+:[^[:space:]/'\'']+@'); then
  real=$(echo "$matches" | grep -viE \
    'user:pass@|USER:PASSWORD|example|placeholder|your[_-]?password|\[PASSWORD\]|\[ref\]|\[YOUR_|:\.\.\.@|:<password>|PASSWORD@|\*\*\*@' \
    || true)
  if [[ -n "$real" ]]; then
    echo "$real" >&2
    fail "Database connection string with embedded credentials found"
  fi
fi

# ── config.toml must use env(...) for secret-bearing keys ─────────────────────
config_src="supabase/config.toml"
if [[ -n "$SCAN_TREE" ]]; then
  if git cat-file -e "${SCAN_TREE}:${config_src}" 2>/dev/null; then
    config_tmp=$(mktemp)
    git show "${SCAN_TREE}:${config_src}" >"$config_tmp"
    config_src="$config_tmp"
    trap 'rm -f "$config_tmp"' EXIT
  else
    config_src=""
  fi
fi

if [[ -n "$config_src" && -f "$config_src" ]]; then
  # Fail closed: secret-bearing keys must use env(...) or be empty.
  bad_config=$(grep -nE '^\s*(secret|password|auth_token|openai_api_key|s3_access_key|s3_secret_key)\s*=\s*"' \
    "$config_src" \
    | grep -vE 'env\(|=\s*""\s*$|#|YOUR_|example|placeholder' || true)
  if [[ -n "$bad_config" ]]; then
    echo "$bad_config" >&2
    fail "supabase/config.toml has non-env secret-looking values (use env(...) placeholders)"
  fi
fi

# ── Web Firebase placeholders (working tree only when not scanning a SHA) ─────
if [[ -z "$SCAN_TREE" ]]; then
  for f in web/index.html web/firebase-messaging-sw.js; do
    [[ -f "$f" ]] || continue
    if grep -nE 'AIza[0-9A-Za-z_-]{30,}' "$f" >/dev/null 2>&1; then
      fail "$f contains a Firebase API key literal (use __FIREBASE_*__ placeholders + CI inject)"
    fi
  done
fi

echo "✅ Security check passed"
