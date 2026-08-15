# Backend behaviour the app depends on

The method signatures in
[`packages/hisab_backend`](../packages/hisab_backend/README.md) say what a
backend is called with. This document says what it has to *do* — the
server-side rules a reimplementer would otherwise discover one bug report at a
time.

Read this alongside [SELF_HOSTING.md](SELF_HOSTING.md), which covers the table
shapes and the sync model.

## Invites

### Tokens

A token is an opaque string. The app never parses it and never derives anything
from it, so generate it however you like as long as it is unguessable — it is
the only credential protecting a group's contents from anyone holding the link.

### Never-expiring is the normal case

`CloudInvites.create` takes a nullable `expiresIn` and a nullable `maxUses`.
Null means *no limit*, not "use a default". The UI's default invite has both
null, so an implementation that quietly substitutes a 7-day expiry breaks the
most common flow a week after anyone uses it.

Validity is therefore:

```
is_active AND (expires_at IS NULL OR expires_at > now())
          AND (max_uses IS NULL OR use_count < max_uses)
```

An invite that fails any of these must make `getByToken` return null rather
than throw. The app renders "this invite is no longer valid" from a null; an
exception surfaces as an error toast instead.

### Accepting is not idempotent, but rejoining is

`accept` has four cases, in this order:

1. **Already a member.** Fail. The app treats this as "you are already in this
   group" and navigates there.
2. **Rejoining.** If a participant exists in the group with this `user_id` and
   a non-null `left_at`, reuse it: clear `left_at`, refresh the name and avatar
   from the user's profile, and link the new membership to it. This is the case
   that matters most — without it, a member who leaves and comes back is a
   stranger to their own expense history, and every share they were part of
   points at a participant nobody is.
3. **Claiming a placeholder.** With `participantId` supplied, link the new
   membership to that existing participant. This is how someone who was being
   tracked by name before they had an account takes over their own row.
4. **New participant.** With `newParticipantName` supplied, create a
   participant with `sort_order` one past the group's current maximum.

Then, in all accepting cases: insert the `group_members` row with the invite's
role, record an `invite_usages` row, and increment `use_count`. An invite that
has just reached `max_uses` is deleted rather than left inert.

### Preview runs unauthenticated

`getByToken`, `previewGroup`, `previewParticipants` and `previewExpenses` are
called before sign-in, from a device with no session. They must work anonymously
and must expose only what the invite's `access_mode` permits — a `standard`
invite reveals the group name and member list; a preview-enabled invite also
reveals participants and expenses.

This is the one place where a token alone authorizes a read. Everything else
requires a session.

### The redirect endpoint

`resolverUrlFor(token)` must resolve to an HTTP endpoint that:

1. Validates the token server-side.
2. Redirects (302) to `<site>/redirect.html?token=<token>` when valid.
3. Redirects to `<site>/redirect.html?error=expired` when not, and
   `?error=missing` when the token parameter is absent.

`redirect.html` ships in this repo. It is what bounces the visitor into the app
via the `com.shenepoy.hisab://invite` deep link, or leaves them on the web app
if it is not installed. Validating server-side is what lets a dead invite say
so before the app opens.

## Membership

- **Leaving.** Refuse when the caller is the sole owner of a group that still
  has other members; the app surfaces that as "transfer ownership first". A
  sole member leaving their own group is fine.
- **Leaving is a soft delete.** Set the participant's `left_at` rather than
  removing the row. Their expense shares must stay intact and keep pointing at
  them, or every balance in the group's history silently changes.
- **Transfer.** Promote the new owner and demote the caller to admin, in one
  transaction. A group with no owner or two owners is unrepresentable in the UI.
- **Archiving a participant** is likewise a soft removal that preserves history.
- **Merging** a placeholder participant into a real member repoints every
  expense share from the placeholder to the member's participant, then removes
  the placeholder. Balances before and after must be identical.

## Notifications

- `claimDeviceToken` takes *exclusive* ownership. Token uniqueness is on the
  token itself, not on `(user_id, token)`: claiming must drop any other user's
  row for the same token. Otherwise a shared or resold device keeps delivering
  someone else's group activity.
- `locale` is a BCP-47 tag stored with the token, because the notification text
  is built server-side. It is re-sent whenever the user changes app language.
- **Notify suppress** is a per-user flag the app sets around a bulk sync. While
  it is true, activity notifications for that user's actions must not be sent.
  Migrating a local database to the cloud inserts thousands of expenses in a
  few seconds; without this, every other member of every shared group gets one
  push per row.
  The app clears the flag when the sync finishes, including on failure, but a
  backend that expires the flag on its own after a few minutes will forgive a
  client that crashes mid-migration.
- Never notify the actor about their own action.

## Account deletion

`deleteMyData` is *not* account deletion. It erases the caller's cloud
footprint while leaving the account able to sign in again, and it must not touch
the local database — the app asks separately whether to keep offline data.

It must:

1. Leave every group, transferring ownership to another member where one
   exists and deleting the group where none does.
2. Delete the caller's device tokens.
3. Delete the caller's invite usages.

`deleteMyDataPreview` returns the counts the confirmation screen states before
the user commits, so it must be computed the same way the deletion is. A
preview that says "1 group will be deleted" and a deletion that removes three
is worse than no preview.

## Telemetry

Opt-in, off by default, and never carrying identity. The app sends an event
name, a timestamp and a free-form data map. Authenticate the endpoint with the
anonymous key, not the user's session.

Dropping events is always correct. The app never retries and never surfaces a
telemetry failure.

## Health

`probe()` answers one question: is this backend responding. It must not throw,
and it should distinguish a suspended backend from an unreachable one, because
the two have different audiences — a paused project is the operator's problem
and the app says so rather than telling the user to check their connection.
