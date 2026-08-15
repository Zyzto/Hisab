/// Invite lifecycle and the unauthenticated preview it powers.
///
/// Rows come back as plain JSON maps; the app parses them into its own domain
/// models. Column names are documented in `docs/BACKEND_BEHAVIOUR.md`.
abstract interface class CloudInvites {
  /// Base URL invite links are built on, without a trailing slash.
  String get linkBaseUrl;

  /// The shareable URL for [token]. The page it resolves to must work for a
  /// logged-out visitor who does not have the app installed.
  String linkFor(String token);

  /// The backend endpoint that resolves [token] and redirects the visitor on
  /// to the app or the web fallback.
  ///
  /// [linkFor] is what you hand to a person; this is where that link ends up.
  /// They differ when invite links are served from a custom domain, and the
  /// web app has to bounce a visitor who landed on the custom-domain path
  /// without the static redirect page having handled it.
  Uri resolverUrlFor(String token);

  /// Resolves a token to its invite plus group. Returns null when the token is
  /// unknown, revoked, or exhausted.
  ///
  /// Callable while unauthenticated — this is how an invited user sees what
  /// they are joining before signing in.
  Future<Map<String, dynamic>?> getByToken(String token);

  /// Creates an invite and returns at least `id` and `token`.
  ///
  /// [expiresIn] null means the invite never expires. [maxUses] null means
  /// unlimited. Admin or owner only.
  Future<Map<String, dynamic>> create(
    String groupId, {
    String? inviteeEmail,
    String? role,
    String? label,
    int? maxUses,
    Duration? expiresIn,
    String accessMode = 'standard',
  });

  /// Redeems [token] and returns the joined group id.
  ///
  /// Exactly one of [participantId] (claim an existing placeholder) or
  /// [newParticipantName] (create a new participant) should be supplied. The
  /// backend must be idempotent: accepting twice returns the same group
  /// without creating a duplicate participant.
  Future<String> accept(
    String token, {
    String? participantId,
    String? newParticipantName,
  });

  /// Permanently disables an invite.
  Future<void> revoke(String inviteId);

  /// Suspends or resumes an invite without destroying it.
  Future<void> toggleActive(String inviteId, bool active);

  /// Read-only preview of the group behind [token], for invites whose access
  /// mode permits previewing. Callable while unauthenticated. Returns null
  /// when the token does not allow a preview.
  Future<Map<String, dynamic>?> previewGroup(String token);

  /// Participants visible in the preview. Callable while unauthenticated.
  Future<List<Map<String, dynamic>>> previewParticipants(String token);

  /// Expenses visible in the preview. Callable while unauthenticated.
  Future<List<Map<String, dynamic>>> previewExpenses(String token);
}
