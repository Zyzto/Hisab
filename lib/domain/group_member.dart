/// Legacy local membership row retained so older databases can be opened.
///
/// New local groups are participant-based. This value is only used when
/// reading a database created by an earlier release.
class GroupMember {
  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    this.participantId,
    required this.joinedAt,
  });

  final String id;
  final String groupId;
  final String userId;
  final String role;
  final String? participantId;
  final DateTime joinedAt;
}
