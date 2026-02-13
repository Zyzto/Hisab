/// Domain entity: a pending invite to join a group.
class GroupInvite {
  final String id;
  final String groupId;
  final String token;
  final String? inviteeEmail;
  final String role;
  final DateTime createdAt;
  final DateTime expiresAt;

  const GroupInvite({
    required this.id,
    required this.groupId,
    required this.token,
    this.inviteeEmail,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  GroupInvite copyWith({
    String? id,
    String? groupId,
    String? token,
    String? inviteeEmail,
    String? role,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return GroupInvite(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      token: token ?? this.token,
      inviteeEmail: inviteeEmail ?? this.inviteeEmail,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
