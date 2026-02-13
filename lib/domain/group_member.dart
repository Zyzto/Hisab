/// Domain entity: a group member (user with role) linking to a group.
class GroupMember {
  final String id;
  final String groupId;
  final String userId;
  final String role;
  final String? participantId;
  final DateTime joinedAt;

  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    this.participantId,
    required this.joinedAt,
  });

  GroupMember copyWith({
    String? id,
    String? groupId,
    String? userId,
    String? role,
    String? participantId,
    DateTime? joinedAt,
  }) {
    return GroupMember(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      participantId: participantId ?? this.participantId,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
