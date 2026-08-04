/// Custom expense tag (category) for a group. User-created, reusable.
/// [iconName] is a Material icon name (e.g. 'restaurant') used to look up IconData.
/// [colorHex] is optional `#RRGGBB`; when null, chrome falls back to a hash palette.
class ExpenseTag {
  final String id;
  final String groupId;
  final String label;
  final String iconName;
  final String? colorHex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseTag({
    required this.id,
    required this.groupId,
    required this.label,
    required this.iconName,
    this.colorHex,
    required this.createdAt,
    required this.updatedAt,
  });

  ExpenseTag copyWith({
    String? id,
    String? groupId,
    String? label,
    String? iconName,
    String? colorHex,
    bool clearColor = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseTag(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      label: label ?? this.label,
      iconName: iconName ?? this.iconName,
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
