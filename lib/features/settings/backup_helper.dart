import 'dart:convert';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import '../../core/repository/group_repository.dart';
import '../../core/repository/participant_repository.dart';
import '../../core/repository/expense_repository.dart';
import '../../core/repository/tag_repository.dart';
import '../../domain/domain.dart';

/// Result of backup export or import.
class BackupResult {
  const BackupResult({this.success = false, this.message, this.path});

  final bool success;
  final String? message;
  final String? path;
}

/// Export all local data to a JSON-serializable map.
/// Uses repository interfaces (backed by PowerSync).
Future<Map<String, dynamic>> exportDataToJson({
  required IGroupRepository groupRepo,
  required IParticipantRepository participantRepo,
  required IExpenseRepository expenseRepo,
  required ITagRepository tagRepo,
}) async {
  final groups = await groupRepo.getAll();
  final participants = <Participant>[];
  final expenses = <Expense>[];
  final expenseTags = <ExpenseTag>[];

  for (final g in groups) {
    participants.addAll(await participantRepo.getByGroupId(g.id));
    expenses.addAll(await expenseRepo.getByGroupId(g.id));
    expenseTags.addAll(await tagRepo.getByGroupId(g.id));
  }

  return {
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'groups': groups.map((g) => _groupToMap(g)).toList(),
    'participants': participants.map((p) => _participantToMap(p)).toList(),
    'expenses': expenses.map((e) => _expenseToMap(e)).toList(),
    'expense_tags': expenseTags.map((t) => _tagToMap(t)).toList(),
  };
}

Map<String, dynamic> _groupToMap(Group g) => {
  'id': g.id,
  'name': g.name,
  'currencyCode': g.currencyCode,
  'createdAt': g.createdAt.toIso8601String(),
  'updatedAt': g.updatedAt.toIso8601String(),
  'settlementMethod': g.settlementMethod.name,
  'treasurerParticipantId': g.treasurerParticipantId,
  'settlementFreezeAt': g.settlementFreezeAt?.millisecondsSinceEpoch,
  'settlementSnapshotJson': g.settlementSnapshotJson,
};

Map<String, dynamic> _participantToMap(Participant p) => {
  'id': p.id,
  'groupId': p.groupId,
  'name': p.name,
  'order': p.order,
  'createdAt': p.createdAt.toIso8601String(),
  'updatedAt': p.updatedAt.toIso8601String(),
};

Map<String, dynamic> _expenseToMap(Expense e) => {
  'id': e.id,
  'groupId': e.groupId,
  'payerParticipantId': e.payerParticipantId,
  'amountCents': e.amountCents,
  'currencyCode': e.currencyCode,
  'title': e.title,
  'description': e.description,
  'date': e.date.toIso8601String(),
  'splitType': e.splitType.name,
  'splitShares': e.splitShares,
  'createdAt': e.createdAt.toIso8601String(),
  'updatedAt': e.updatedAt.toIso8601String(),
  'transactionType': e.transactionType.name,
  'toParticipantId': e.toParticipantId,
  'tag': e.tag,
  'lineItems': e.lineItems?.map((l) => l.toJson()).toList(),
  'receiptImagePath': e.receiptImagePath,
};

Map<String, dynamic> _tagToMap(ExpenseTag t) => {
  'id': t.id,
  'groupId': t.groupId,
  'label': t.label,
  'iconName': t.iconName,
  'createdAt': t.createdAt.toIso8601String(),
  'updatedAt': t.updatedAt.toIso8601String(),
};

/// Validate and parse backup JSON. Returns null if invalid.
BackupData? parseBackupJson(String jsonString) {
  try {
    final map = jsonDecode(jsonString) as Map<String, dynamic>?;
    if (map == null) return null;
    final version = map['version'] as int?;
    if (version == null || version != 1) return null;
    final groups =
        (map['groups'] as List<dynamic>?)
            ?.map((e) => _mapToGroup(e as Map<String, dynamic>))
            .toList() ??
        [];
    final participants =
        (map['participants'] as List<dynamic>?)
            ?.map((e) => _mapToParticipant(e as Map<String, dynamic>))
            .toList() ??
        [];
    final expenses =
        (map['expenses'] as List<dynamic>?)
            ?.map((e) => _mapToExpense(e as Map<String, dynamic>))
            .toList() ??
        [];
    final expenseTags =
        (map['expense_tags'] as List<dynamic>?)
            ?.map((e) => _mapToTag(e as Map<String, dynamic>))
            .toList() ??
        [];
    return BackupData(
      groups: groups,
      participants: participants,
      expenses: expenses,
      expenseTags: expenseTags,
    );
  } catch (e) {
    Log.warning('Backup parse failed', error: e);
    return null;
  }
}

Group _mapToGroup(Map<String, dynamic> m) {
  SettlementMethod method = SettlementMethod.greedy;
  final methodStr = m['settlementMethod'] as String?;
  if (methodStr != null) {
    switch (methodStr) {
      case 'pairwise':
        method = SettlementMethod.pairwise;
        break;
      case 'greedy':
        method = SettlementMethod.greedy;
        break;
      case 'consolidated':
        method = SettlementMethod.consolidated;
        break;
      case 'treasurer':
        method = SettlementMethod.treasurer;
        break;
    }
  }
  return Group(
    id: m['id'] as String,
    name: m['name'] as String,
    currencyCode: m['currencyCode'] as String,
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
    settlementMethod: method,
    treasurerParticipantId: m['treasurerParticipantId'] as String?,
    settlementFreezeAt: m['settlementFreezeAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(m['settlementFreezeAt'] as int)
        : null,
    settlementSnapshotJson: m['settlementSnapshotJson'] as String?,
  );
}

Participant _mapToParticipant(Map<String, dynamic> m) => Participant(
  id: m['id'] as String,
  groupId: m['groupId'] as String,
  name: m['name'] as String,
  order: m['order'] as int,
  createdAt: DateTime.parse(m['createdAt'] as String),
  updatedAt: DateTime.parse(m['updatedAt'] as String),
);

Expense _mapToExpense(Map<String, dynamic> m) {
  final lineItems = m['lineItems'] as List<dynamic>?;
  return Expense(
    id: m['id'] as String,
    groupId: m['groupId'] as String,
    payerParticipantId: m['payerParticipantId'] as String,
    amountCents: m['amountCents'] as int,
    currencyCode: m['currencyCode'] as String,
    title: m['title'] as String,
    description: m['description'] as String?,
    date: DateTime.parse(m['date'] as String),
    splitType: SplitType.values.firstWhere(
      (e) => e.name == m['splitType'],
      orElse: () => SplitType.equal,
    ),
    splitShares:
        (m['splitShares'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ) ??
        {},
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
    transactionType: TransactionType.values.firstWhere(
      (e) => e.name == (m['transactionType'] ?? 'expense'),
      orElse: () => TransactionType.expense,
    ),
    toParticipantId: m['toParticipantId'] as String?,
    tag: m['tag'] as String?,
    lineItems: lineItems
        ?.map((e) => ReceiptLineItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    receiptImagePath: m['receiptImagePath'] as String?,
  );
}

ExpenseTag _mapToTag(Map<String, dynamic> m) => ExpenseTag(
  id: m['id'] as String,
  groupId: m['groupId'] as String,
  label: m['label'] as String,
  iconName: m['iconName'] as String,
  createdAt: DateTime.parse(m['createdAt'] as String),
  updatedAt: DateTime.parse(m['updatedAt'] as String),
);

class BackupData {
  const BackupData({
    required this.groups,
    required this.participants,
    required this.expenses,
    required this.expenseTags,
  });

  final List<Group> groups;
  final List<Participant> participants;
  final List<Expense> expenses;
  final List<ExpenseTag> expenseTags;
}
