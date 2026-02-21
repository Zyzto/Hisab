import 'settlement_method.dart';

/// Domain entity: a group (trip/event) with participants and expenses.
/// [id] is a UUID string.
class Group {
  final String id;
  final String name;
  final String currencyCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SettlementMethod settlementMethod;
  final String? treasurerParticipantId;
  final DateTime? settlementFreezeAt;
  final String? settlementSnapshotJson;
  final String? ownerId;
  final bool allowMemberAddExpense;
  final bool allowMemberChangeSettings;
  final String? icon;
  final int? color;
  final DateTime? archivedAt;

  const Group({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.createdAt,
    required this.updatedAt,
    this.settlementMethod = SettlementMethod.greedy,
    this.treasurerParticipantId,
    this.settlementFreezeAt,
    this.settlementSnapshotJson,
    this.ownerId,
    this.allowMemberAddExpense = true,
    this.allowMemberChangeSettings = true,
    this.icon,
    this.color,
    this.archivedAt,
  });

  bool get isSettlementFrozen => settlementFreezeAt != null;
  bool get isArchived => archivedAt != null;

  Group copyWith({
    String? id,
    String? name,
    String? currencyCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    SettlementMethod? settlementMethod,
    String? treasurerParticipantId,
    DateTime? settlementFreezeAt,
    String? settlementSnapshotJson,
    String? ownerId,
    bool? allowMemberAddExpense,
    bool? allowMemberChangeSettings,
    String? icon,
    int? color,
    DateTime? archivedAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      currencyCode: currencyCode ?? this.currencyCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settlementMethod: settlementMethod ?? this.settlementMethod,
      treasurerParticipantId:
          treasurerParticipantId ?? this.treasurerParticipantId,
      settlementFreezeAt: settlementFreezeAt ?? this.settlementFreezeAt,
      settlementSnapshotJson:
          settlementSnapshotJson ?? this.settlementSnapshotJson,
      ownerId: ownerId ?? this.ownerId,
      allowMemberAddExpense:
          allowMemberAddExpense ?? this.allowMemberAddExpense,
      allowMemberChangeSettings:
          allowMemberChangeSettings ?? this.allowMemberChangeSettings,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  /// Returns a copy with settlement freeze cleared (unfrozen).
  Group copyWithUnfreeze() => Group(
    id: id,
    name: name,
    currencyCode: currencyCode,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    settlementMethod: settlementMethod,
    treasurerParticipantId: treasurerParticipantId,
    settlementFreezeAt: null,
    settlementSnapshotJson: null,
    ownerId: ownerId,
    allowMemberAddExpense: allowMemberAddExpense,
    allowMemberChangeSettings: allowMemberChangeSettings,
    icon: icon,
    color: color,
    archivedAt: archivedAt,
  );
}
