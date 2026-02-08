/// Domain entity: a participant in a group.
class Participant {
  final String id;
  final String groupId;
  final String name;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Participant({
    required this.id,
    required this.groupId,
    required this.name,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  Participant copyWith({
    String? id,
    String? groupId,
    String? name,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Participant(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
