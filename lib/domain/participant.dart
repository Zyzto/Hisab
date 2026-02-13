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
  final DateTime createdAt;
  final DateTime updatedAt;

  const Participant({
    required this.id,
    required this.groupId,
    required this.name,
    required this.order,
    this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  Participant copyWith({
    String? id,
    String? groupId,
    String? name,
    int? order,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Participant(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      order: order ?? this.order,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
