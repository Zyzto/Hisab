/// Domain entity: a group (trip/event) with participants and expenses.
/// [id] is a string (Convex id or "local_$intId" for Drift).
class Group {
  final String id;
  final String name;
  final String currencyCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Group({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.createdAt,
    required this.updatedAt,
  });

  Group copyWith({
    String? id,
    String? name,
    String? currencyCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      currencyCode: currencyCode ?? this.currencyCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
