# hisab_backend

The contract between the Hisab app and a cloud backend.

Hisab is offline-first. The local SQLite database is the source of truth for
everything the UI reads, and a backend only moves rows in and out of it. That
makes the seam small enough to write down, which is what this package is: nine
interfaces, four models, and a registry.

The app depends on this package and nothing else backend-shaped. A backend is a
separate package named `hisab_cloud` that implements [`CloudBackend`] and calls
`registerCloudBackend`. Swapping backends is a `dependency_overrides` change,
not a code change — see [docs/SELF_HOSTING.md](../../docs/SELF_HOSTING.md).

## Registration

```dart
import 'package:hisab_backend/hisab_backend.dart';

Future<void> registerHisabCloud() async {
  registerCloudBackend(MyBackend());
}
```

`main()` calls `registerHisabCloud()` once before `runApp`, then
`CloudBackend.initialize()`. A package that registers nothing leaves
`cloudAvailable` false and the app runs entirely offline, with every online
affordance hidden. There is no partial mode.

## Error contract

Every method that can fail throws `CloudException` and nothing else. Vendor
exceptions must be translated at the boundary, because the app branches on
`CloudErrorKind` to decide between retrying, re-authenticating and surfacing a
message:

| Kind | Meaning | What the app does |
| --- | --- | --- |
| `auth` | Not signed in, expired, or forbidden | Stops; may prompt to re-authenticate |
| `network` | Connectivity failure or timeout | Retries with backoff; queues the write |
| `invalidRequest` | Malformed or disallowed by policy | Surfaces the message; does not retry |
| `notFound` | Row absent or invisible to this user | Treats as a miss |
| `server` | 5xx or rate limit | Retries with backoff |
| `unknown` | Anything else | Surfaces the message |

`isTransient` and `isAuthError` are what `sync_errors.dart` actually reads; set
`kind` and `statusCode` accurately and both fall out correctly.

Getters never throw. `CloudAuth.currentUser` returns null when signed out
rather than raising, because it is read during widget builds.

## The nine facets

### CloudAuth

Email sign-in and sign-up, magic links, Google and GitHub OAuth, sign-out,
profile and password updates, and the session stream.

`authStateChanges` must emit `CloudAuthEvent.initialSession` once on subscribe,
so a listener attached after startup still converges on the current state.

`completeWebRedirect()` finishes an OAuth or magic-link redirect that landed
back on the web app. It must not throw, and it must be a no-op off the web and
when there is nothing to complete.

`signInWithOAuth` returns whether the flow was *launched*, not whether it
succeeded; success arrives on `authStateChanges`.

### CloudSync

Bulk row transport for the sync engine, and the only facet the pull loop uses.
The `get*` methods return rows as plain JSON maps keyed by column name. Reads
scoped by an id list must return an empty list, not throw, when handed an empty
list.

`upsert` / `update` / `updateWhere` / `delete` drain the local `pending_writes`
outbox. See [docs/SELF_HOSTING.md](../../docs/SELF_HOSTING.md) for the tables
and their columns, and [docs/BACKEND_BEHAVIOUR.md](../../docs/BACKEND_BEHAVIOUR.md)
for the outbox semantics.

`updateWhere` must still be scoped to what the caller may write. An
implementation that trusts the column and value it is handed lets any user
rewrite every row in the table.

### CloudGroups

Membership changes that must be authorized server-side: kick, leave, role
change, ownership transfer, participant merge and participant archive.

None of these can be a plain row write. Each changes another user's access or
rewrites shared history, so the backend has to check the caller's role itself.
The app hides the affordance in the UI, which is not a security boundary.

### CloudInvites

Invite lifecycle plus the unauthenticated preview it powers. `getByToken`,
`previewGroup`, `previewParticipants` and `previewExpenses` are callable while
signed out — that is how an invited person sees what they are joining before
they create an account.

`linkFor(token)` is the URL you hand to a person. `resolverUrlFor(token)` is
where that URL ends up. They differ when invite links are served from a custom
domain.

### CloudNotifications

Push token registration and the suppression flag. Displaying a notification is
entirely client-side; only the handshake crosses the seam.

`claimDeviceToken` must be idempotent and must *transfer* the token when a
different account previously claimed it. Otherwise a shared device keeps
delivering to whoever signed in first.

`setNotifySuppress(true)` wraps a bulk sync so migrating a large local database
does not fan out one notification per row to every other group member.

### CloudFiles

Receipt images and feedback screenshots. Both methods return null on failure
rather than throwing: an image that fails to upload degrades an expense, it
does not invalidate it, and the row is already committed locally by then.

Returned URLs must be fetchable by every member of the owning group.

### CloudAccount

`deleteMyDataPreview()` returns the counts the confirmation screen states
before the user commits: `groups_where_owner`, `group_memberships`,
`device_tokens_count`, `invite_usages_count`, `sole_member_group_count`.

`deleteMyData()` erases the caller's cloud footprint and must not touch local
data — the app asks about that separately.

### CloudTelemetry

Opt-in diagnostics. `send` is fire-and-forget: it must never throw and never
block a user action. `isEnabled` false means the app skips collection entirely
rather than buffering events nobody will read.

### CloudHealth

A reachability probe behind the in-app service status sheet. `probe()` must not
throw. Distinguishing `paused` from `unreachable` matters because a paused
backend is the operator's problem, and the app says so instead of blaming the
user's connection.

## Models

`CloudUser`, `CloudSession`, `CloudAuthState`, `CloudAuthResponse`,
`CloudException`, `CloudHealthResult` and the `CloudOAuthProvider`,
`CloudAuthEvent`, `CloudErrorKind` and `CloudHealthStatus` enums.

`CloudUser.metadata` is free-form; the app reads `full_name`, `name` and
`avatar_id` from it. `CloudUser.provider` is the lowercase identity provider
(`email`, `google`, `github`); Hisab only offers a password change when it is
`email`.

## Auth redirect

`resolveAuthRedirectUrl` and the two deep link constants are exported here
rather than left to each backend, because the app registers the scheme in its
own manifests. A backend must accept `hisabAuthCallbackDeepLink`
(`com.shenepoy.hisab://callback`) in its redirect allowlist, and should keep
accepting `legacyHisabAuthCallbackDeepLink` until installs predating the scheme
rename age out.
