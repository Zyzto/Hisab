import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import '../database/app_database.dart' as db;
import '../database/daos/group_dao.dart';
import '../database/daos/participant_dao.dart';
import '../database/daos/expense_dao.dart';
import '../../domain/domain.dart';
import 'group_repository.dart';
import 'participant_repository.dart';
import 'expense_repository.dart';

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
    return intToLocalId(id);
  }

  @override
  Future<void> update(Group group) async {
    final intId = localIdToInt(group.id);
    if (intId == null) return;
    final row = db.Group(
      id: intId,
      name: group.name,
      currencyCode: group.currencyCode,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
    );
    await _groupDao.updateGroup(row);
  }

  @override
  Future<void> delete(String id) async {
    final intId = localIdToInt(id);
    if (intId != null) await _groupDao.deleteGroup(intId);
  }

  Group _toDomain(db.Group row) {
    return Group(
      id: intToLocalId(row.id),
      name: row.name,
      currencyCode: row.currencyCode,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
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
    return intToLocalId(id);
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
  }

  @override
  Future<void> delete(String id) async {
    final intId = localIdToInt(id);
    if (intId != null) await _participantDao.deleteParticipant(intId);
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
    final companion = db.ExpensesCompanion.insert(
      groupId: groupIntId,
      payerParticipantId: payerIntId,
      amountCents: expense.amountCents,
      currencyCode: expense.currencyCode,
      title: expense.title,
      date: expense.date,
      splitType: expense.splitType.name,
      splitSharesJson: Value(_encodeSplitShares(expense.splitShares)),
      type: Value(expense.transactionType.name),
      toParticipantId: toIntId != null ? Value(toIntId) : const Value.absent(),
    );
    final id = await _expenseDao.insertExpense(companion);
    final domainId = intToLocalId(id);
    Log.info('Expense created: id=$domainId groupId=${expense.groupId} title="${expense.title}" amountCents=${expense.amountCents} currencyCode=${expense.currencyCode}');
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
      date: expense.date,
      splitType: expense.splitType.name,
      splitSharesJson: _encodeSplitShares(expense.splitShares),
      type: expense.transactionType.name,
      toParticipantId: toIntId,
      createdAt: expense.createdAt,
      updatedAt: expense.updatedAt,
    );
    await _expenseDao.updateExpense(row);
    Log.info('Expense updated: id=${expense.id} title="${expense.title}" amountCents=${expense.amountCents}');
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
    return Expense(
      id: intToLocalId(row.id),
      groupId: intToLocalId(row.groupId),
      payerParticipantId: intToLocalId(row.payerParticipantId),
      amountCents: row.amountCents,
      currencyCode: row.currencyCode,
      title: row.title,
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
    );
  }
}
