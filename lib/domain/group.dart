import 'settlement_method.dart';

/// Domain entity: a group (trip/event) with participants and expenses.
/// [id] is a UUID string.
///
/// When [isPersonal] is true, the group is "my expenses only": single participant,
/// minimized UI (no People/Balance tabs, no split in expense form, no invites).
/// [budgetAmountCents] is optional and used for personal "My budget" display.
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
  final bool allowExpenseAsOtherParticipant;
  final String? icon;
  final int? color;
  final DateTime? archivedAt;
  /// True for personal (my-expenses-only) groups; minimal UI, no invites.
  final bool isPersonal;
  /// Optional budget in group currency (cents); used when [isPersonal].
  final int? budgetAmountCents;

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
    this.allowExpenseAsOtherParticipant = true,
    this.icon,
    this.color,
    this.archivedAt,
    this.isPersonal = false,
    this.budgetAmountCents,
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
    bool? allowExpenseAsOtherParticipant,
    String? icon,
    int? color,
    DateTime? archivedAt,
    bool? isPersonal,
    int? budgetAmountCents,
    bool clearBudgetAmountCents = false,
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
      allowExpenseAsOtherParticipant:
          allowExpenseAsOtherParticipant ?? this.allowExpenseAsOtherParticipant,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      archivedAt: archivedAt ?? this.archivedAt,
      isPersonal: isPersonal ?? this.isPersonal,
      budgetAmountCents: clearBudgetAmountCents
          ? null
          : (budgetAmountCents ?? this.budgetAmountCents),
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
    allowExpenseAsOtherParticipant: allowExpenseAsOtherParticipant,
    icon: icon,
    color: color,
    archivedAt: archivedAt,
    isPersonal: isPersonal,
    budgetAmountCents: budgetAmountCents,
  );
}
