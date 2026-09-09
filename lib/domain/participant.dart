/// Domain entity: a participant in a group.
///
/// A participant can be:
/// - Linked to an auth user ([userId] != null) — auto-created when a member joins.
/// - Standalone (no [userId]) — a non-person entity like "Cash" or "Hotel",
///   or a friend who doesn't have the app.
class Participant {
  final String id;
  final String groupId;
  final String name;
  final int order;

  /// Auth user id this participant belongs to. Null for standalone participants.
  final String? userId;

  /// Avatar identifier (matches a key in [predefinedAvatars]).
  /// Null means the user hasn't set one (falls back to initials).
  final String? avatarId;

  /// When set, this participant is treated as left/archived (hidden from main list; expense history kept).
  final DateTime? leftAt;

  /// Optional parent in the recursive household directory.
  final String? parentParticipantId;

  /// Number of unnamed people represented directly by this participant.
  final int unnamedDependentCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Participant({
    required this.id,
    required this.groupId,
    required this.name,
    required this.order,
    this.userId,
    this.avatarId,
    this.leftAt,
    this.parentParticipantId,
    this.unnamedDependentCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  int get directHouseholdSize => 1 + unnamedDependentCount;

  Participant copyWith({
    String? id,
    String? groupId,
    String? name,
    int? order,
    String? userId,
    String? avatarId,
    DateTime? leftAt,
    String? parentParticipantId,
    bool clearParentParticipantId = false,
    int? unnamedDependentCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Participant(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      order: order ?? this.order,
      userId: userId ?? this.userId,
      avatarId: avatarId ?? this.avatarId,
      leftAt: leftAt ?? this.leftAt,
      parentParticipantId: clearParentParticipantId
          ? null
          : (parentParticipantId ?? this.parentParticipantId),
      unnamedDependentCount:
          unnamedDependentCount ?? this.unnamedDependentCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
