/// Bulk row transport for the sync engine.
///
/// The app owns the local database and all merge logic. This facet only moves
/// rows: the `get*` methods are the pull side, and [upsert] / [update] /
/// [delete] are the push side draining the local `pending_writes` outbox.
///
/// All reads return rows as plain JSON maps whose keys are the column names in
/// `docs/SELF_HOSTING.md`. Reads scoped by id list must return an empty list
/// — not throw — when given an empty list.
abstract interface class CloudSync {
  /// The signed-in user's id, or null. Mirrors `CloudAuth.currentUser?.id` and
  /// exists so the sync engine does not need the auth facet.
  String? get currentUserId;

  /// Rows of `{group_id: ...}` for every group [userId] belongs to.
  Future<List<Map<String, dynamic>>> getGroupIdsForUser(String userId);

  Future<List<Map<String, dynamic>>> getGroups(List<String> groupIds);
  Future<List<Map<String, dynamic>>> getMembers(List<String> groupIds);
  Future<List<Map<String, dynamic>>> getParticipants(List<String> groupIds);
  Future<List<Map<String, dynamic>>> getExpenses(List<String> groupIds);
  Future<List<Map<String, dynamic>>> getTags(List<String> groupIds);
  Future<List<Map<String, dynamic>>> getInvites(List<String> groupIds);

  /// Tolerant read: returns an empty list rather than throwing when the
  /// backend does not expose invite usage.
  Future<List<Map<String, dynamic>>> getInviteUsages(List<String> inviteIds);

  /// Tolerant read, newest first, capped by the backend.
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId);

  /// Inserts [data], replacing any existing row that collides.
  ///
  /// [table] is one of the five writable tables listed in
  /// `docs/SELF_HOSTING.md`. Collision is decided by primary key unless
  /// [conflictColumns] names a different unique constraint — migrating a local
  /// database re-sends the owner's membership, which is unique on
  /// `(group_id, user_id)` rather than on `id`.
  Future<void> upsert(
    String table,
    Map<String, dynamic> data, {
    List<String>? conflictColumns,
  });

  Future<void> update(String table, Map<String, dynamic> data, String id);

  /// Patches every row in [table] whose [column] equals [value], or is null
  /// when [value] is null.
  ///
  /// Needed for the two edits that are not keyed by primary key: renaming a
  /// person updates their participant row in every group at once, and marking
  /// all notifications read matches on `read_at IS NULL`.
  ///
  /// The backend must still scope this to what the caller may write. An
  /// unscoped implementation lets any user rewrite every row in the table.
  Future<void> updateWhere(
    String table,
    Map<String, dynamic> data, {
    required String column,
    required Object? value,
  });

  Future<void> delete(String table, String id);
}
