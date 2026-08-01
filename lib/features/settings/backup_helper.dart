import 'dart:convert';

import 'package:flutter_logging_service/flutter_logging_service.dart';

import '../../core/receipt/receipt_utils.dart';
import '../../core/repository/expense_repository.dart';
import '../../core/repository/group_repository.dart';
import '../../core/repository/participant_repository.dart';
import '../../core/repository/tag_repository.dart';
import '../../domain/domain.dart';
import 'backup_limits.dart';

const int kBackupSchemaVersion = 2;

/// Export groups (optionally filtered) to a JSON-serializable map (schema v2).
Future<Map<String, dynamic>> exportDataToJson({
  required IGroupRepository groupRepo,
  required IParticipantRepository participantRepo,
  required IExpenseRepository expenseRepo,
  required ITagRepository tagRepo,
  Set<String>? groupIdsFilter,
}) async {
  var groups = await groupRepo.getAll();
  if (groupIdsFilter != null) {
    groups = groups.where((g) => groupIdsFilter.contains(g.id)).toList();
  }
  final groupIds = groups.map((g) => g.id).toSet();

  final allParticipants = await participantRepo.getAll();
  final allExpenses = await expenseRepo.getAll();
  final allTags = await tagRepo.getAll();

  final participants = allParticipants
      .where((p) => groupIds.contains(p.groupId))
      .toList();
  final expenses = allExpenses
      .where((e) => groupIds.contains(e.groupId))
      .toList();
  final expenseTags = allTags
      .where((t) => groupIds.contains(t.groupId))
      .toList();

  final localArchivedGroupIds = (await groupRepo.getLocallyArchivedGroupIds())
      .where(groupIds.contains)
      .toList();

  return {
    'version': kBackupSchemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'groups': groups.map(_groupToMap).toList(),
    'participants': participants.map(_participantToMap).toList(),
    'expenses': expenses.map(_expenseToMap).toList(),
    'expense_tags': expenseTags.map(_tagToMap).toList(),
    'localArchivedGroupIds': localArchivedGroupIds,
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
  'allowMemberAddExpense': g.allowMemberAddExpense,
  'allowMemberChangeSettings': g.allowMemberChangeSettings,
  'allowExpenseAsOtherParticipant': g.allowExpenseAsOtherParticipant,
  'allowMemberSettleForOthers': g.allowMemberSettleForOthers,
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
  'avatarId': p.avatarId,
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
  'exchangeRate': e.exchangeRate,
  'baseAmountCents': e.baseAmountCents,
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
  'imagePath': e.imagePath,
  'imagePaths': e.imagePaths,
};

Map<String, dynamic> _tagToMap(ExpenseTag t) => {
  'id': t.id,
  'groupId': t.groupId,
  'label': t.label,
  'iconName': t.iconName,
  'createdAt': t.createdAt.toIso8601String(),
  'updatedAt': t.updatedAt.toIso8601String(),
};

class BackupParseResult {
  const BackupParseResult({
    this.data,
    this.errorMessageKey,
    this.schemaVersion,
    this.warnings = const [],
  });

  final BackupData? data;
  final String? errorMessageKey;
  final int? schemaVersion;
  final List<String> warnings;
}

/// Validate and parse backup JSON (schema v1 or v2).
BackupParseResult parseBackupJson(String jsonString) {
  if (jsonString.length > BackupLimits.maxFileBytes) {
    return const BackupParseResult(errorMessageKey: 'backup_parse_too_large');
  }
  try {
    final map = jsonDecode(jsonString) as Map<String, dynamic>?;
    if (map == null) {
      return const BackupParseResult(
        errorMessageKey: 'backup_parse_invalid_format',
      );
    }
    final version = map['version'] as int?;
    if (version == null || (version != 1 && version != 2)) {
      return const BackupParseResult(
        errorMessageKey: 'backup_parse_unsupported_version',
      );
    }
    final warnings = <String>[];
    if (version == 1) {
      warnings.add('backup_warning_v1_fx');
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
            ?.map((e) => _mapToExpense(e as Map<String, dynamic>, version))
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

    if (groups.length > BackupLimits.maxGroups ||
        participants.length > BackupLimits.maxParticipants ||
        expenses.length > BackupLimits.maxExpenses ||
        expenseTags.length > BackupLimits.maxTags) {
      return const BackupParseResult(
        errorMessageKey: 'backup_parse_too_large',
      );
    }

    return BackupParseResult(
      data: BackupData(
        groups: groups,
        participants: participants,
        expenses: expenses,
        expenseTags: expenseTags,
        localArchivedGroupIds: localArchivedGroupIds,
      ),
      schemaVersion: version,
      warnings: warnings,
    );
  } on FormatException catch (_) {
    return const BackupParseResult(
      errorMessageKey: 'backup_parse_invalid_format',
    );
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
  final name = _clampStr(m['name'] as String? ?? '', BackupLimits.maxGroupName);
  final icon = _clampStrNullable(
    m['icon'] as String?,
    BackupLimits.maxGroupIcon,
  );
  final snapshot = m['settlementSnapshotJson'] as String?;
  if (snapshot != null &&
      snapshot.length > BackupLimits.maxSnapshotJsonBytes) {
    throw FormatException('settlement snapshot too large');
  }
  return Group(
    id: m['id'] as String,
    name: name,
    currencyCode: _currencyCode(m['currencyCode'] as String?),
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
    settlementMethod: method,
    treasurerParticipantId: m['treasurerParticipantId'] as String?,
    settlementFreezeAt: m['settlementFreezeAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(m['settlementFreezeAt'] as int)
        : null,
    settlementSnapshotJson: snapshot,
    allowMemberAddExpense: m['allowMemberAddExpense'] != false,
    allowMemberChangeSettings: m['allowMemberChangeSettings'] != false,
    allowExpenseAsOtherParticipant:
        m['allowExpenseAsOtherParticipant'] != false,
    allowMemberSettleForOthers: m['allowMemberSettleForOthers'] == true,
    icon: icon,
    color: (m['color'] as num?)?.toInt(),
    archivedAt: archivedAt != null
        ? DateTime.tryParse(archivedAt as String)
        : null,
    isPersonal: m['isPersonal'] == true,
    budgetAmountCents: (m['budgetAmountCents'] as num?)?.toInt(),
  );
}

Participant _mapToParticipant(Map<String, dynamic> m) {
  final leftAt = m['leftAt'] as String?;
  return Participant(
    id: m['id'] as String,
    groupId: m['groupId'] as String,
    name: _clampStr(
      m['name'] as String? ?? '',
      BackupLimits.maxParticipantName,
    ),
    order: (m['order'] as num?)?.toInt() ?? 0,
    avatarId: m['avatarId'] as String?,
    leftAt: leftAt != null ? DateTime.tryParse(leftAt) : null,
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
  );
}

Expense _mapToExpense(Map<String, dynamic> m, int version) {
  final lineItems = m['lineItems'] as List<dynamic>?;
  if (lineItems != null && lineItems.length > BackupLimits.maxLineItems) {
    throw FormatException('too many line items');
  }
  final shares =
      (m['splitShares'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ) ??
      {};
  if (shares.length > BackupLimits.maxSplitShareEntries) {
    throw FormatException('too many split shares');
  }
  final description = _clampStrNullable(
    m['description'] as String?,
    BackupLimits.maxDescription,
  );
  var imagePaths = _backupImagePaths(m);
  // Import never persists remote URLs (strip at parse for restore safety).
  if (imagePaths != null) {
    imagePaths = imagePaths
        .where((p) => !isNetworkImagePath(p))
        .take(BackupLimits.maxImagePaths)
        .map((p) => _clampStr(p, BackupLimits.maxImagePathLength))
        .where((p) => p.isNotEmpty)
        .toList();
    if (imagePaths.isEmpty) imagePaths = null;
  }
  return Expense(
    id: m['id'] as String,
    groupId: m['groupId'] as String,
    payerParticipantId: m['payerParticipantId'] as String,
    amountCents: (m['amountCents'] as num).toInt(),
    currencyCode: _currencyCode(m['currencyCode'] as String?),
    exchangeRate: version >= 2
        ? (m['exchangeRate'] as num?)?.toDouble() ?? 1.0
        : 1.0,
    baseAmountCents: version >= 2
        ? (m['baseAmountCents'] as num?)?.toInt()
        : null,
    title: _clampStr(m['title'] as String? ?? '', BackupLimits.maxExpenseTitle),
    description: description,
    date: DateTime.parse(m['date'] as String),
    splitType: SplitType.values.firstWhere(
      (e) => e.name == m['splitType'],
      orElse: () => SplitType.equal,
    ),
    splitShares: shares,
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
    transactionType: TransactionType.values.firstWhere(
      (e) => e.name == (m['transactionType'] ?? 'expense'),
      orElse: () => TransactionType.expense,
    ),
    toParticipantId: m['toParticipantId'] as String?,
    tag: _clampStrNullable(m['tag'] as String?, BackupLimits.maxTagLabel),
    lineItems: lineItems
        ?.map((e) => ReceiptLineItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    imagePath: imagePaths?.isNotEmpty == true ? imagePaths!.first : null,
    imagePaths: imagePaths,
  );
}

List<String>? _backupImagePaths(Map<String, dynamic> m) {
  final raw = m['imagePaths'] ?? m['receiptImagePaths'];
  if (raw is List) {
    final list = raw.whereType<String>().where((s) => s.isNotEmpty).toList();
    return list.isEmpty ? null : list;
  }
  final single = (m['imagePath'] ?? m['receiptImagePath']) as String?;
  return single != null && single.isNotEmpty ? [single] : null;
}

ExpenseTag _mapToTag(Map<String, dynamic> m) => ExpenseTag(
  id: m['id'] as String,
  groupId: m['groupId'] as String,
  label: _clampStr(m['label'] as String? ?? '', BackupLimits.maxTagLabel),
  iconName: _clampStr(
    m['iconName'] as String? ?? 'label',
    BackupLimits.maxTagIconName,
  ),
  createdAt: DateTime.parse(m['createdAt'] as String),
  updatedAt: DateTime.parse(m['updatedAt'] as String),
);

String _clampStr(String s, int max) =>
    s.length <= max ? s : s.substring(0, max);

String? _clampStrNullable(String? s, int max) {
  if (s == null) return null;
  return _clampStr(s, max);
}

/// Remap split share keys through [participantIds].
Map<String, int> remapSplitShares(
  Map<String, int> shares,
  Map<String, String> participantIds,
) {
  final out = <String, int>{};
  for (final e in shares.entries) {
    final newId = participantIds[e.key];
    if (newId != null) out[newId] = e.value;
  }
  return out;
}

/// Remap participant and expense IDs inside a settlement snapshot JSON string.
String? remapSettlementSnapshotJson(
  String? json,
  Map<String, String> participantIds,
  Map<String, String> expenseIds,
) {
  if (json == null || json.isEmpty) return json;
  try {
    final snap = SettlementSnapshot.fromJsonString(json);
    final balances = snap.balances
        .map(
          (b) => ParticipantBalance(
            participantId: participantIds[b.participantId] ?? b.participantId,
            balanceCents: b.balanceCents,
            currencyCode: b.currencyCode,
          ),
        )
        .toList();
    final settlements = snap.settlements.map((s) {
      final items = s.items
          ?.map(
            (i) => SettlementItem(
              expenseId: expenseIds[i.expenseId] ?? i.expenseId,
              title: i.title,
              amountCents: i.amountCents,
            ),
          )
          .toList();
      return SettlementTransaction(
        fromParticipantId:
            participantIds[s.fromParticipantId] ?? s.fromParticipantId,
        toParticipantId: participantIds[s.toParticipantId] ?? s.toParticipantId,
        amountCents: s.amountCents,
        currencyCode: s.currencyCode,
        items: items,
      );
    }).toList();
    return SettlementSnapshot(
      frozenAt: snap.frozenAt,
      balances: balances,
      settlements: settlements,
    ).toJsonString();
  } catch (e) {
    Log.warning('Failed to remap settlement snapshot', error: e);
    return json;
  }
}

String _currencyCode(String? raw) {
  final c = (raw ?? 'USD').trim().toUpperCase();
  if (c.length == 3) return c;
  return 'USD';
}

/// Strip network image paths from an expense (import safety).
Expense stripRemoteImagePaths(Expense e) {
  final paths = e.effectiveImageUrls
      .where((p) => !isNetworkImagePath(p))
      .toList();
  return Expense(
    id: e.id,
    groupId: e.groupId,
    payerParticipantId: e.payerParticipantId,
    amountCents: e.amountCents,
    currencyCode: e.currencyCode,
    exchangeRate: e.exchangeRate,
    baseAmountCents: e.baseAmountCents,
    title: e.title,
    description: e.description,
    date: e.date,
    splitType: e.splitType,
    splitShares: e.splitShares,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt,
    transactionType: e.transactionType,
    toParticipantId: e.toParticipantId,
    tag: e.tag,
    lineItems: e.lineItems,
    imagePath: paths.isNotEmpty ? paths.first : null,
    imagePaths: paths.isNotEmpty ? paths : null,
  );
}

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
