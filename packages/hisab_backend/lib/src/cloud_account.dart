/// Account-wide destructive operations.
abstract interface class CloudAccount {
  /// Counts of what [deleteMyData] would affect, so the confirmation screen can
  /// state the consequences before the user commits.
  ///
  /// Returns the keys `groups_where_owner`, `group_memberships`,
  /// `device_tokens_count`, `invite_usages_count` and
  /// `sole_member_group_count`, or null when the backend has nothing to report.
  Future<Map<String, dynamic>?> deleteMyDataPreview();

  /// Erases the caller's cloud footprint: leaves every group, transferring
  /// ownership where another member remains and deleting the group where none
  /// does, then removes their device tokens and invite usages.
  ///
  /// Must not touch the local database — the app decides separately whether to
  /// keep offline data.
  Future<void> deleteMyData();
}
