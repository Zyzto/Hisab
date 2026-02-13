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
  final bool allowMemberAddParticipant;
  final bool allowMemberChangeSettings;
  final bool requireParticipantAssignment;

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
    this.allowMemberAddParticipant = true,
    this.allowMemberChangeSettings = true,
    this.requireParticipantAssignment = false,
  });

  bool get isSettlementFrozen => settlementFreezeAt != null;

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
    bool? allowMemberAddParticipant,
    bool? allowMemberChangeSettings,
    bool? requireParticipantAssignment,
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
      allowMemberAddParticipant:
          allowMemberAddParticipant ?? this.allowMemberAddParticipant,
      allowMemberChangeSettings:
          allowMemberChangeSettings ?? this.allowMemberChangeSettings,
      requireParticipantAssignment:
          requireParticipantAssignment ?? this.requireParticipantAssignment,
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
    allowMemberAddParticipant: allowMemberAddParticipant,
    allowMemberChangeSettings: allowMemberChangeSettings,
    requireParticipantAssignment: requireParticipantAssignment,
  );
}
