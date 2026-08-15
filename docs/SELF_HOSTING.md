# Self-hosting a Hisab backend

This repository ships a *specification*, not a deployable server. The hosted
Hisab backend is proprietary: its migrations, row-level security policies and
`SECURITY DEFINER` functions are not published. What is published is everything
you need to write your own — the contract, the table shapes, and the behaviour
the app depends on.

Be honest with yourself about the size of that job before starting. The
transport is small; the authorization is not. **You must implement your own
authorization.** Every rule about who may edit which expense, remove which
member or read which group lives in the backend, and none of it is here.

If you only want to use Hisab, you do not need any of this. The offline build
in this repo's releases is fully functional on one device.

## The shape of it

```
your_backend/            a Dart package named hisab_cloud
  lib/hisab_cloud.dart   exports Future<void> registerHisabCloud()
  pubspec.yaml           depends on hisab_backend
```

```yaml
# pubspec_overrides.yaml in the app repo (gitignored)
dependency_overrides:
  googleai_dart: 3.0.0
  hisab_backend:
    path: packages/hisab_backend
  hisab_cloud:
    path: ../your_backend
```

Then `flutter pub get` and build normally.

Three things have to be in that file at once, and leaving any of them out fails
in a way that does not name the cause:

- **`googleai_dart`** — an overrides file *replaces* the whole
  `dependency_overrides` block from `pubspec.yaml` rather than merging into it,
  so the existing pin has to be repeated or the langchain build breaks.
- **`hisab_cloud`** — the point of the exercise.
- **`hisab_backend`** — if your package declares it from a different source
  (a git dependency, say) than the app's path dependency, pub refuses to
  resolve one package from two sources until an override picks the winner.

Also: `pubspec.lock` is committed and resolves the offline stub. Run
`flutter pub get`, never `--enforce-lockfile`, and do not commit the lockfile
your overlay produces.

## Implementing the contract

Start from [`packages/hisab_backend/README.md`](../packages/hisab_backend/README.md),
which documents all nine facets method by method. The short version:

1. Implement `CloudBackend` and its nine facet getters.
2. Translate every vendor error into `CloudException` with an accurate
   `CloudErrorKind`. The app's retry, queue and sign-out logic reads nothing
   else.
3. Call `registerCloudBackend(yourBackend)` from `registerHisabCloud()`.
4. Do your connecting in `CloudBackend.initialize()`, which the app awaits
   during startup before the first frame.

A backend that registers nothing is a valid backend: the app runs offline.
That is exactly what the stub in `packages/hisab_cloud` does.

## The eight synced tables

`CloudSync` pulls these. Column names are the map keys, and they match
[`lib/core/database/powersync_schema.dart`](../lib/core/database/powersync_schema.dart),
which is the authoritative list — the local mirror and the remote table have
the same shape by construction.

| Table | Pulled by | Notes |
| --- | --- | --- |
| `groups` | `getGroups(groupIds)` | `owner_id` is a user id, not a participant id |
| `group_members` | `getMembers(groupIds)` | Unique on `(group_id, user_id)` |
| `participants` | `getParticipants(groupIds)` | A participant may exist with no `user_id` |
| `expenses` | `getExpenses(groupIds)` | Splits and line items are JSON strings |
| `expense_tags` | `getTags(groupIds)` | |
| `group_invites` | `getInvites(groupIds)` | |
| `invite_usages` | `getInviteUsages(inviteIds)` | Tolerant: may return `[]` |
| `user_notifications` | `getUserNotifications(userId)` | Newest first, capped |

`getGroupIdsForUser(userId)` returns `{group_id: ...}` rows and drives
everything else: the app asks which groups you are in, then pulls those.

Two of these are deliberately tolerant. `getInviteUsages` and
`getUserNotifications` return an empty list rather than throwing when
unsupported, so a backend can omit invite analytics or the notification feed
and still sync everything else.

### Types on the wire

The local schema is SQLite, so booleans arrive as `0`/`1` integers, money as
integer `*_cents`, and timestamps as ISO-8601 strings. Return them in those
shapes; the app does not coerce.

## The pull model

There is no delta protocol. On sync the app asks for the group ids the user
belongs to, pulls every row for those groups, and replaces its local mirror.
Rows the backend no longer returns are dropped locally.

The practical consequence: whatever your authorization rules are, they express
themselves as which rows come back. If a user loses access to a group, stop
returning its rows and the local copy goes away on the next sync.

## The pending_writes outbox

Local edits are written to SQLite immediately and queued in a `pending_writes`
table. On the next successful sync the queue is drained in FIFO order, oldest
first, one row at a time, through `upsert` / `update` / `delete`.

Only five tables may appear in the outbox:

```
groups, group_members, participants, expenses, expense_tags
```

Anything else is rejected client-side before it reaches you. Invites,
membership changes and account deletion are not queued at all — they go through
`CloudGroups`, `CloudInvites` and `CloudAccount`, and they simply fail while
offline, because none of them can be replayed safely later.

FIFO matters: an expense insert can be followed by an update to the same
expense in the same drain. Do not reorder or batch them.

A failed write stops the drain. Transient failures (`network`, `server`) leave
the queue intact for the next attempt; anything else is surfaced to the user.

`upsert` takes an optional `conflictColumns`. Migrating a local database
re-sends the owner's own membership row, which is unique on
`(group_id, user_id)` rather than on `id`, so a plain primary-key upsert
duplicates it.

## Authorization is yours

The app hides buttons a user should not press. That is a nicety, not a
boundary — every method on the contract is reachable from a modified client.
At minimum you need rules for:

- Reading: a user sees a group only through a `group_members` row.
- Writing expenses, participants and tags: scoped to groups the caller belongs
  to, and further scoped by the group's own permission flags
  (`allow_member_add_expense`, `allow_member_add_participant`,
  `allow_member_change_settings`, `allow_member_settle_for_others`,
  `allow_expense_as_other_participant`, `require_participant_assignment`).
- `CloudGroups`: role checks. Only an owner may transfer ownership; only an
  owner or admin may kick or change roles.
- `CloudInvites`: preview methods run unauthenticated and must expose only what
  the invite's access mode permits.
- `CloudSync.updateWhere`: scope it, or it is a rewrite-anything primitive.

[docs/BACKEND_BEHAVIOUR.md](BACKEND_BEHAVIOUR.md) covers the non-obvious
server-side contracts — invite lifecycle, participant dedupe, notify suppress,
account deletion — that you would otherwise find by trial and error.

## What is not published

The hosted backend's migrations, RLS policies, `SECURITY DEFINER` functions,
edge functions and their deployment tooling. Those are the product being sold,
and the licence on this repo (AGPL-3.0) covers the client, not them.
