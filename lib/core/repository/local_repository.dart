import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import '../database/app_database.dart' as db;
import '../database/daos/group_dao.dart';
import '../database/daos/participant_dao.dart';
import '../database/daos/expense_dao.dart';
import '../database/daos/expense_tag_dao.dart';
import '../../domain/domain.dart';
import 'group_repository.dart';
import 'participant_repository.dart';
import 'expense_repository.dart';
import 'tag_repository.dart';

/// Prefix for local (Drift) ids when exposed as domain String ids.
const String localIdPrefix = 'local_';

int? localIdToInt(String domainId) {
  if (!domainId.startsWith(localIdPrefix)) return null;
  return int.tryParse(domainId.substring(localIdPrefix.length));
}

String intToLocalId(int id) => '$localIdPrefix$id';

SplitType _parseSplitType(String? s) {
  switch (s) {
    case 'equal':
      return SplitType.equal;
    case 'parts':
      return SplitType.parts;
    case 'amounts':
      return SplitType.amounts;
    case 'percentage':
    case 'uneven':
      return SplitType.equal; // legacy
    default:
      return SplitType.equal;
  }
}

/// Local implementation using Drift. Maps int ids to "local_$id" in domain.
class LocalGroupRepository implements IGroupRepository {
  LocalGroupRepository(this._groupDao);

  final GroupDao _groupDao;

  @override
  Future<List<Group>> getAll() async {
    final rows = await _groupDao.getAll();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<Group>> watchAll() {
    return _groupDao.watchAll().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<Group?> getById(String id) async {
    final intId = localIdToInt(id);
    if (intId == null) return null;
    final row = await _groupDao.getById(intId);
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<String> create(String name, String currencyCode) async {
    final companion = db.GroupsCompanion.insert(
      name: name,
      currencyCode: currencyCode,
    );
    final id = await _groupDao.insertGroup(companion);
    final domainId = intToLocalId(id);
    Log.info(
      'Group created: id=$domainId name="$name" currencyCode=$currencyCode',
    );
    return domainId;
  }

  @override
  Future<void> update(Group group) async {
    final intId = localIdToInt(group.id);
    if (intId == null) return;
    final treasurerInt = group.treasurerParticipantId != null
        ? localIdToInt(group.treasurerParticipantId!)
        : null;
    final row = db.Group(
      id: intId,
      name: group.name,
      currencyCode: group.currencyCode,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
      settlementMethod: group.settlementMethod.name,
      treasurerParticipantId: treasurerInt,
      settlementFreezeAt: group.settlementFreezeAt,
      settlementSnapshotJson: group.settlementSnapshotJson,
    );
    await _groupDao.updateGroup(row);
    Log.info('Group updated: id=${group.id} name="${group.name}"');
  }

  @override
  Future<void> delete(String id) async {
    final intId = localIdToInt(id);
    if (intId != null) {
      await _groupDao.deleteGroup(intId);
      Log.info('Group deleted: id=$id');
    }
  }

  @override
  Future<void> freezeSettlement(
    String groupId,
    SettlementSnapshot snapshot,
  ) async {
    final group = await getById(groupId);
    if (group == null) return;
    await update(
      group.copyWith(
        settlementFreezeAt: snapshot.frozenAt,
        settlementSnapshotJson: snapshot.toJsonString(),
      ),
    );
    Log.info('Settlement frozen: groupId=$groupId');
  }

  @override
  Future<void> unfreezeSettlement(String groupId) async {
    final group = await getById(groupId);
    if (group == null) return;
    await update(group.copyWithUnfreeze());
    Log.info('Settlement unfrozen: groupId=$groupId');
  }

  SettlementMethod _parseSettlementMethod(String? s) {
    if (s == null) return SettlementMethod.greedy;
    switch (s) {
      case 'pairwise':
        return SettlementMethod.pairwise;
      case 'greedy':
        return SettlementMethod.greedy;
      case 'consolidated':
        return SettlementMethod.consolidated;
      case 'treasurer':
        return SettlementMethod.treasurer;
      default:
        return SettlementMethod.greedy;
    }
  }

  Group _toDomain(db.Group row) {
    return Group(
      id: intToLocalId(row.id),
      name: row.name,
      currencyCode: row.currencyCode,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      settlementMethod: _parseSettlementMethod(row.settlementMethod),
      treasurerParticipantId: row.treasurerParticipantId != null
          ? intToLocalId(row.treasurerParticipantId!)
          : null,
      settlementFreezeAt: row.settlementFreezeAt,
      settlementSnapshotJson: row.settlementSnapshotJson,
    );
  }
}

class LocalParticipantRepository implements IParticipantRepository {
  LocalParticipantRepository(this._participantDao);

  final ParticipantDao _participantDao;

  @override
  Future<List<Participant>> getByGroupId(String groupId) async {
    final intId = localIdToInt(groupId);
    if (intId == null) return [];
    final rows = await _participantDao.getByGroupId(intId);
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<Participant>> watchByGroupId(String groupId) {
    final intId = localIdToInt(groupId);
    if (intId == null) return Stream.value([]);
    return _participantDao
        .watchByGroupId(intId)
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<Participant?> getById(String id) async {
    final intId = localIdToInt(id);
    if (intId == null) return null;
    final row = await _participantDao.getById(intId);
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<String> create(String groupId, String name, int order) async {
    final groupIntId = localIdToInt(groupId);
    if (groupIntId == null) throw ArgumentError('Invalid groupId');
    final companion = db.ParticipantsCompanion.insert(
      groupId: groupIntId,
      name: name,
      order: Value(order),
    );
    final id = await _participantDao.insertParticipant(companion);
    final domainId = intToLocalId(id);
    Log.info('Participant created: id=$domainId groupId=$groupId name="$name"');
    return domainId;
  }

  @override
  Future<void> update(Participant participant) async {
    final intId = localIdToInt(participant.id);
    if (intId == null) return;
    final row = db.Participant(
      id: intId,
      groupId: localIdToInt(participant.groupId)!,
      name: participant.name,
      order: participant.order,
      createdAt: participant.createdAt,
      updatedAt: participant.updatedAt,
    );
    await _participantDao.updateParticipant(row);
    Log.info(
      'Participant updated: id=${participant.id} name="${participant.name}"',
    );
  }

  @override
  Future<void> delete(String id) async {
    final intId = localIdToInt(id);
    if (intId != null) {
      await _participantDao.deleteParticipant(intId);
      Log.info('Participant deleted: id=$id');
    }
  }

  Participant _toDomain(db.Participant row) {
    return Participant(
      id: intToLocalId(row.id),
      groupId: intToLocalId(row.groupId),
      name: row.name,
      order: row.order,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

class LocalExpenseRepository implements IExpenseRepository {
  LocalExpenseRepository(this._expenseDao);

  final ExpenseDao _expenseDao;

  static Map<String, int> _parseSplitShares(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final map = jsonDecode(json) as Map<String, dynamic>?;
      if (map == null) return {};
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (e) {
      Log.warning('Local repository: splitShares parse failed', error: e);
      return {};
    }
  }

  static String _encodeSplitShares(Map<String, int> map) {
    return jsonEncode(map);
  }

  static String? _encodeLineItems(List<ReceiptLineItem>? list) {
    if (list == null || list.isEmpty) return null;
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }

  static List<ReceiptLineItem> _parseLineItems(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = jsonDecode(json) as List<dynamic>?;
      if (list == null) return const [];
      return list
          .map((e) => ReceiptLineItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Log.warning('Local repository: lineItems parse failed', error: e);
      return const [];
    }
  }

  @override
  Future<List<Expense>> getByGroupId(String groupId) async {
    final intId = localIdToInt(groupId);
    if (intId == null) return [];
    final rows = await _expenseDao.getByGroupId(intId);
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<Expense>> watchByGroupId(String groupId) {
    final intId = localIdToInt(groupId);
    if (intId == null) return Stream.value([]);
    return _expenseDao
        .watchByGroupId(intId)
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<Expense?> getById(String id) async {
    final intId = localIdToInt(id);
    if (intId == null) return null;
    final row = await _expenseDao.getById(intId);
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<String> create(Expense expense) async {
    final groupIntId = localIdToInt(expense.groupId);
    final payerIntId = localIdToInt(expense.payerParticipantId);
    if (groupIntId == null || payerIntId == null) {
      throw ArgumentError('Invalid groupId or payerParticipantId');
    }
    final toIntId = expense.toParticipantId != null
        ? localIdToInt(expense.toParticipantId!)
        : null;
    final lineItemsEnc = _encodeLineItems(expense.lineItems);
    final companion = db.ExpensesCompanion.insert(
      groupId: groupIntId,
      payerParticipantId: payerIntId,
      amountCents: expense.amountCents,
      currencyCode: expense.currencyCode,
      title: expense.title,
      description:
          expense.description != null && expense.description!.isNotEmpty
          ? Value(expense.description!)
          : const Value.absent(),
      date: expense.date,
      splitType: expense.splitType.name,
      splitSharesJson: Value(_encodeSplitShares(expense.splitShares)),
      type: Value(expense.transactionType.name),
      toParticipantId: toIntId != null ? Value(toIntId) : const Value.absent(),
      tag: expense.tag != null ? Value(expense.tag!) : const Value.absent(),
      lineItemsJson: lineItemsEnc != null
          ? Value(lineItemsEnc)
          : const Value.absent(),
      receiptImagePath:
          expense.receiptImagePath != null &&
              expense.receiptImagePath!.isNotEmpty
          ? Value(expense.receiptImagePath!)
          : const Value.absent(),
    );
    final id = await _expenseDao.insertExpense(companion);
    final domainId = intToLocalId(id);
    Log.info(
      'Expense created: id=$domainId groupId=${expense.groupId} title="${expense.title}" amountCents=${expense.amountCents} currencyCode=${expense.currencyCode}',
    );
    return domainId;
  }

  @override
  Future<void> update(Expense expense) async {
    final intId = localIdToInt(expense.id);
    if (intId == null) return;
    final toIntId = expense.toParticipantId != null
        ? localIdToInt(expense.toParticipantId!)
        : null;
    final row = db.Expense(
      id: intId,
      groupId: localIdToInt(expense.groupId)!,
      payerParticipantId: localIdToInt(expense.payerParticipantId)!,
      amountCents: expense.amountCents,
      currencyCode: expense.currencyCode,
      title: expense.title,
      description: expense.description,
      date: expense.date,
      splitType: expense.splitType.name,
      splitSharesJson: _encodeSplitShares(expense.splitShares),
      type: expense.transactionType.name,
      toParticipantId: toIntId,
      tag: expense.tag,
      lineItemsJson: _encodeLineItems(expense.lineItems),
      receiptImagePath: expense.receiptImagePath,
      createdAt: expense.createdAt,
      updatedAt: expense.updatedAt,
    );
    await _expenseDao.updateExpense(row);
    Log.info(
      'Expense updated: id=${expense.id} title="${expense.title}" amountCents=${expense.amountCents}',
    );
  }

  @override
  Future<void> delete(String id) async {
    final intId = localIdToInt(id);
    if (intId != null) {
      await _expenseDao.deleteExpense(intId);
      Log.info('Expense deleted: id=$id');
    }
  }

  Expense _toDomain(db.Expense row) {
    final lineItems = _parseLineItems(row.lineItemsJson);
    return Expense(
      id: intToLocalId(row.id),
      groupId: intToLocalId(row.groupId),
      payerParticipantId: intToLocalId(row.payerParticipantId),
      amountCents: row.amountCents,
      currencyCode: row.currencyCode,
      title: row.title,
      description: row.description,
      date: row.date,
      splitType: _parseSplitType(row.splitType),
      splitShares: _parseSplitShares(row.splitSharesJson),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      transactionType: TransactionType.values.firstWhere(
        (e) => e.name == row.type,
        orElse: () => TransactionType.expense,
      ),
      toParticipantId: row.toParticipantId != null
          ? intToLocalId(row.toParticipantId!)
          : null,
      tag: row.tag,
      lineItems: lineItems.isEmpty ? null : lineItems,
      receiptImagePath: row.receiptImagePath,
    );
  }
}

class LocalTagRepository implements ITagRepository {
  LocalTagRepository(this._dao);

  final ExpenseTagDao _dao;

  @override
  Future<List<ExpenseTag>> getByGroupId(String groupId) async {
    final intId = localIdToInt(groupId);
    if (intId == null) return [];
    final rows = await _dao.getByGroupId(intId);
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<ExpenseTag>> watchByGroupId(String groupId) {
    final intId = localIdToInt(groupId);
    if (intId == null) return Stream.value([]);
    return _dao
        .watchByGroupId(intId)
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<ExpenseTag?> getById(String id) async {
    final intId = localIdToInt(id);
    if (intId == null) return null;
    final row = await _dao.getById(intId);
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<String> create(String groupId, String label, String iconName) async {
    final groupIntId = localIdToInt(groupId);
    if (groupIntId == null) throw ArgumentError('Invalid groupId');
    final companion = db.ExpenseTagsCompanion.insert(
      groupId: groupIntId,
      label: label,
      iconName: iconName,
    );
    final id = await _dao.insertTag(companion);
    return intToLocalId(id);
  }

  @override
  Future<void> update(ExpenseTag tag) async {
    final intId = localIdToInt(tag.id);
    if (intId == null) return;
    final groupIntId = localIdToInt(tag.groupId);
    if (groupIntId == null) return;
    final row = db.ExpenseTagRow(
      id: intId,
      groupId: groupIntId,
      label: tag.label,
      iconName: tag.iconName,
      createdAt: tag.createdAt,
      updatedAt: tag.updatedAt,
    );
    await _dao.updateTag(row);
  }

  @override
  Future<void> delete(String id) async {
    final intId = localIdToInt(id);
    if (intId != null) await _dao.deleteTag(intId);
  }

  ExpenseTag _toDomain(db.ExpenseTagRow row) {
    return ExpenseTag(
      id: intToLocalId(row.id),
      groupId: intToLocalId(row.groupId),
      label: row.label,
      iconName: row.iconName,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
