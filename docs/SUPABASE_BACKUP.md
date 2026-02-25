# Supabase database backup

This document describes how to create a backup of your Hisab Supabase database (schema + data). Use this for disaster recovery, cloning a project, or migrating to another Supabase project.

## Options

| Method | Best for | Requirements |
|--------|----------|--------------|
| **Dashboard** | One-off snapshot (Pro: point-in-time recovery) | Supabase dashboard access |
| **pg_dump** | Full SQL dump (schema + data), scriptable | `psql` / PostgreSQL client, DB connection string |
| **Supabase CLI** | Local dev / linked project | `supabase` CLI, linked project |

---

## 1. Dashboard (Supabase)

1. Open [supabase.com/dashboard](https://supabase.com/dashboard) and select your project.
2. Go to **Project Settings** → **Database**.
3. **Backups** (Pro plan): Supabase runs daily backups and offers point-in-time recovery. Use the dashboard to restore to a previous time if needed.
4. **Manual export**: On free tier there is no built-in “download backup” in the UI. Use **pg_dump** (below) or **SQL Editor** to export data (e.g. `COPY ... TO STDOUT` for tables) if you need a file.

---

## 2. pg_dump (recommended for full dump)

You need the **database connection string** (includes password):

1. In the Supabase dashboard: **Project Settings** → **Database**.
2. Under **Connection string**, choose **URI**.
3. Copy the URI and replace `[YOUR-PASSWORD]` with your database password.  
   Example format:  
   `postgresql://postgres.[project-ref]:[YOUR-PASSWORD]@aws-0-[region].pooler.supabase.com:6543/postgres`  
   For pg_dump, **session mode** (port **5432**) is often more reliable than transaction mode (6543). Use the **Session** tab if available.
4. Run a dump:

```bash
# Full dump (schema + data) to a single SQL file
pg_dump "$DATABASE_URL" --no-owner --no-acl -f hisab_backup_$(date +%Y%m%d_%H%M%S).sql

# Or: schema only (no data)
pg_dump "$DATABASE_URL" --no-owner --no-acl --schema-only -f hisab_schema.sql

# Or: data only (assumes schema already exists)
pg_dump "$DATABASE_URL" --no-owner --no-acl --data-only -f hisab_data.sql
```

Set `DATABASE_URL` in the environment (or use the URI in place of `$DATABASE_URL`). Do not commit the URL or dump files that contain real data; add `*.sql` (or backup paths) to `.gitignore` if storing dumps in the repo tree.

**Restore from dump:**

```bash
psql "$DATABASE_URL" -f hisab_backup_YYYYMMDD_HHMMSS.sql
```

Typically you restore to a new/empty database; restoring over an existing one may conflict with data.

---

## 3. Supabase CLI

If the project is linked to the Supabase CLI:

```bash
supabase db dump -f hisab_backup.sql
```

See [Supabase CLI reference](https://supabase.com/docs/guides/cli/local-development#database-dump) for options (e.g. schema only, specific tables).

---

## 4. Script in this repo

A helper script is provided to run **pg_dump** with a timestamped filename:

- **Script:** `scripts/backup-supabase.sh`
- **Usage:** Set `SUPABASE_DB_URL` (or `DATABASE_URL`) to your Postgres connection URI, then run from the repo root:
  ```bash
  export SUPABASE_DB_URL='postgresql://postgres.[ref]:[PASSWORD]@...'
  ./scripts/backup-supabase.sh
  ```
- **Options:** First argument: `schema` (schema only), `data` (data only), or omit for full dump.
- **Output:** `supabase_backups/hisab_backup_YYYYMMDD_HHMMSS.sql`. The directory `supabase_backups/` is in `.gitignore`; do not commit backup files.

Run it only from an environment where the connection string is kept secret (e.g. your machine or a secure CI secret).

---

## What gets backed up

A full dump includes:

- **Schema:** Tables, indexes, triggers, RLS policies, functions, and other objects in the `public` (and any used) schema.
- **Data:** All rows in tables such as `groups`, `group_members`, `participants`, `expenses`, `expense_tags`, `group_invites`, `invite_usages`, `device_tokens`, `telemetry`, etc.

Auth data (`auth.users`, etc.) is in the `auth` schema. To back up auth as well, include that schema in your pg_dump (e.g. `--schema=public --schema=auth` or no `--schema` for all). Restoring auth may require Supabase-specific steps; for most Hisab use cases, backing up `public` is enough.

---

## Security

- **Never** commit database URLs or backup files containing real user data to the repo.
- Add backup output directories or dump patterns to `.gitignore` (e.g. `scripts/backups/`, `*.sql` in scripts).
- Run backups only from a trusted environment; restrict who has access to the Supabase database password and dump files.

---

## Using Supabase MCP (IDE)

When the **Supabase MCP** server is enabled in the IDE (e.g. Cursor), you can use it for backup-related tasks without leaving the editor:

- **`list_tables`** — Verify schema (tables, columns, RLS) before or after a backup/restore.
- **`execute_sql`** — Run read-only queries (e.g. row counts, spot-check data) or export-friendly SQL. For a full dump you still need pg_dump or the dashboard; MCP is useful for ad-hoc checks.
- **`list_migrations`** — Confirm which migrations are applied so a restore target matches expectations.
- **`get_advisors`** — Security/performance suggestions for the project.

Tool schemas live under `.cursor/projects/.../mcps/<supabase-server>/tools/*.json`. Check the tool descriptor before calling (e.g. `project_id`, `query` for `execute_sql`). See [CODEBASE.md](CODEBASE.md) § MCP available in the IDE and § How to use Supabase MCP.

---

## See also

- [SUPABASE_SETUP.md](SUPABASE_SETUP.md) — Database migrations and schema
- [DELETE_ACCOUNT.md](DELETE_ACCOUNT.md) — User-facing data and account deletion
