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
  final groupIds = groups.map((g) => g.id).toSet();

  final allParticipants = await participantRepo.getAll();
  final allExpenses = await expenseRepo.getAll();
  final allTags = await tagRepo.getAll();

  final participants = allParticipants.where((p) => groupIds.contains(p.groupId)).toList();
  final expenses = allExpenses.where((e) => groupIds.contains(e.groupId)).toList();
  final expenseTags = allTags.where((t) => groupIds.contains(t.groupId)).toList();

  final localArchivedGroupIds =
      await groupRepo.getLocallyArchivedGroupIds();

  return {
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'groups': groups.map((g) => _groupToMap(g)).toList(),
    'participants': participants.map((p) => _participantToMap(p)).toList(),
    'expenses': expenses.map((e) => _expenseToMap(e)).toList(),
    'expense_tags': expenseTags.map((t) => _tagToMap(t)).toList(),
    'localArchivedGroupIds': localArchivedGroupIds.toList(),
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
  'icon': g.icon,
  'color': g.color,
  'archivedAt': g.archivedAt?.toIso8601String(),
  'isPersonal': g.isPersonal,
  'budgetAmountCents': g.budgetAmountCents,
};

Map<String, dynamic> _participantToMap(Participant p) => {
  'id': p.id,
  'groupId': p.groupId,
  'name': p.name,
  'order': p.order,
  'leftAt': p.leftAt?.toIso8601String(),
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
  'receiptImagePaths': e.receiptImagePaths,
};

Map<String, dynamic> _tagToMap(ExpenseTag t) => {
  'id': t.id,
  'groupId': t.groupId,
  'label': t.label,
  'iconName': t.iconName,
  'createdAt': t.createdAt.toIso8601String(),
  'updatedAt': t.updatedAt.toIso8601String(),
};

/// Result of parsing a backup JSON string. [data] is non-null on success;
/// [errorMessageKey] is a translation key for the UI when parsing failed.
class BackupParseResult {
  const BackupParseResult({this.data, this.errorMessageKey});

  final BackupData? data;
  /// Translation key (e.g. backup_parse_unsupported_version) for UI to show.
  final String? errorMessageKey;
}

/// Validate and parse backup JSON. Returns [BackupParseResult] with [data]
/// on success or [errorMessageKey] set when invalid.
BackupParseResult parseBackupJson(String jsonString) {
  try {
    final map = jsonDecode(jsonString) as Map<String, dynamic>?;
    if (map == null) {
      return const BackupParseResult(errorMessageKey: 'backup_parse_invalid_format');
    }
    final version = map['version'] as int?;
    if (version == null || version != 1) {
      return const BackupParseResult(errorMessageKey: 'backup_parse_unsupported_version');
    }
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
    final localArchivedGroupIds =
        (map['localArchivedGroupIds'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];
    return BackupParseResult(
      data: BackupData(
        groups: groups,
        participants: participants,
        expenses: expenses,
        expenseTags: expenseTags,
        localArchivedGroupIds: localArchivedGroupIds,
      ),
    );
  } on FormatException catch (_) {
    return const BackupParseResult(errorMessageKey: 'backup_parse_invalid_format');
  } catch (e) {
    Log.warning('Backup parse failed', error: e);
    return const BackupParseResult(errorMessageKey: 'backup_parse_failed');
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
  final archivedAt = m['archivedAt'];
  final isPersonal = m['isPersonal'] == true;
  final budgetAmountCents = (m['budgetAmountCents'] as num?)?.toInt();
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
    icon: m['icon'] as String?,
    color: (m['color'] as num?)?.toInt(),
    archivedAt: archivedAt != null ? DateTime.tryParse(archivedAt as String) : null,
    isPersonal: isPersonal,
    budgetAmountCents: budgetAmountCents,
  );
}

Participant _mapToParticipant(Map<String, dynamic> m) {
  final leftAt = m['leftAt'] as String?;
  return Participant(
    id: m['id'] as String,
    groupId: m['groupId'] as String,
    name: m['name'] as String,
    order: m['order'] as int,
    leftAt: leftAt != null ? DateTime.tryParse(leftAt) : null,
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
  );
}

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
    receiptImagePath: _backupReceiptImagePath(m),
    receiptImagePaths: _backupReceiptImagePaths(m),
  );
}

String? _backupReceiptImagePath(Map<String, dynamic> m) {
  final paths = _backupReceiptImagePaths(m);
  if (paths != null && paths.isNotEmpty) return paths.first;
  return m['receiptImagePath'] as String?;
}

List<String>? _backupReceiptImagePaths(Map<String, dynamic> m) {
  final raw = m['receiptImagePaths'];
  if (raw is List) {
    final list = raw.whereType<String>().where((s) => s.isNotEmpty).toList();
    return list.isEmpty ? null : list;
  }
  final single = m['receiptImagePath'] as String?;
  return single != null && single.isNotEmpty ? [single] : null;
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
    this.localArchivedGroupIds = const [],
  });

  final List<Group> groups;
  final List<Participant> participants;
  final List<Expense> expenses;
  final List<ExpenseTag> expenseTags;
  final List<String> localArchivedGroupIds;
}
