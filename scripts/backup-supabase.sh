#!/usr/bin/env bash
# Create a backup of the Hisab Supabase database using pg_dump.
#
# Prerequisites:
#   - PostgreSQL client tools (pg_dump) installed
#   - Database connection URI with password
#
# Usage:
#   export SUPABASE_DB_URL='postgresql://postgres.[ref]:[PASSWORD]@aws-0-[region].pooler.supabase.com:5432/postgres'
#   ./scripts/backup-supabase.sh
#
# Options (first argument):
#   schema  - schema only (no data)
#   data    - data only (assumes schema exists)
#   (none)  - full dump (default)
#
# Output: supabase_backups/hisab_backup_YYYYMMDD_HHMMSS.sql
# The directory supabase_backups/ is in .gitignore; do not commit backups.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$REPO_ROOT/supabase_backups}"
MODE="${1:-full}"

URL="${SUPABASE_DB_URL:-$DATABASE_URL}"
if [ -z "$URL" ]; then
  echo "Error: Set SUPABASE_DB_URL or DATABASE_URL to your Postgres connection URI." >&2
  echo "Example: postgresql://postgres.[ref]:[PASSWORD]@aws-0-[region].pooler.supabase.com:5432/postgres" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILE="$BACKUP_DIR/hisab_backup_${TIMESTAMP}.sql"

case "$MODE" in
  schema)
    echo "Dumping schema only to $FILE"
    pg_dump "$URL" --no-owner --no-acl --schema-only -f "$FILE"
    ;;
  data)
    echo "Dumping data only to $FILE"
    pg_dump "$URL" --no-owner --no-acl --data-only -f "$FILE"
    ;;
  full|*)
    echo "Dumping full database to $FILE"
    pg_dump "$URL" --no-owner --no-acl -f "$FILE"
    ;;
esac

echo "Done: $FILE ($(du -h "$FILE" | cut -f1))"
