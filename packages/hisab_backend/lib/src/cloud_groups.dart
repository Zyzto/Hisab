/// Membership operations that must be authorized server-side.
///
/// Every method here changes another user's access or rewrites shared history,
/// so none of them can be expressed as a plain row write the way ordinary
/// expense edits are. A backend must enforce the caller's role itself; the app
/// only hides the affordance in the UI, which is not a security boundary.
///
/// All methods throw [CloudException] with [CloudErrorKind.auth] when the
/// caller lacks the required role.
abstract interface class CloudGroups {
  /// Removes [memberId] from [groupId]. Owner or admin only.
  Future<void> kickMember(String groupId, String memberId);

  /// Removes the caller from [groupId]. The backend must refuse when the
  /// caller is the sole owner of a group that still has other members.
  Future<void> leaveGroup(String groupId);

  /// [role] is one of `owner`, `admin`, `member`.
  Future<void> updateMemberRole(String groupId, String memberId, String role);

  /// Promotes [newOwnerMemberId] to owner and demotes the caller to admin.
  Future<void> transferOwnership(String groupId, String newOwnerMemberId);

  /// Folds a placeholder participant into a real member, repointing every
  /// expense share from [participantId] to [memberId]'s participant.
  Future<void> mergeParticipantWithMember(
    String groupId,
    String participantId,
    String memberId,
  );

  /// Soft-removes a participant, preserving their expense history.
  Future<void> archiveParticipant(String groupId, String participantId);
}
