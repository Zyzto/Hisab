import 'dart:async';
import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import '../../domain/domain.dart';
import 'group_repository.dart';
import 'participant_repository.dart';
import 'expense_repository.dart';

/// Convex implementation. Uses ConvexClient.instance (must be initialized when Local Only is off).
/// Convex ids are strings; no mapping needed.

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

class ConvexGroupRepository implements IGroupRepository {
  @override
  Future<List<Group>> getAll() async {
    final client = ConvexClient.instance;
    final raw = await client.query('groups:list', {});
    final list =
        jsonDecode(raw.isNotEmpty ? raw : '[]') as List<dynamic>? ?? [];
    return list.map((e) => _groupFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<Group>> watchAll() {
    return _subscribeList('groups:list', {}, _groupFromJson);
  }

  @override
  Future<Group?> getById(String id) async {
    final raw = await ConvexClient.instance.query('groups:get', {'id': id});
    if (raw.isEmpty) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>?;
    return map != null ? _groupFromJson(map) : null;
  }

  @override
  Future<String> create(String name, String currencyCode) async {
    final raw = await ConvexClient.instance.mutation(
      name: 'groups:create',
      args: {'name': name, 'currencyCode': currencyCode},
    );
    return raw as String? ?? '';
  }

  @override
  Future<void> update(Group group) async {
    await ConvexClient.instance.mutation(
      name: 'groups:update',
      args: {
        'id': group.id,
        'name': group.name,
        'currencyCode': group.currencyCode,
        'updatedAt': group.updatedAt.millisecondsSinceEpoch,
      },
    );
  }

  @override
  Future<void> delete(String id) async {
    await ConvexClient.instance.mutation(
      name: 'groups:remove',
      args: {'id': id},
    );
  }

  Group _groupFromJson(Map<String, dynamic> j) {
    return Group(
      id: j['_id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      currencyCode: j['currencyCode'] as String? ?? 'USD',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (j['createdAt'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (j['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class ConvexParticipantRepository implements IParticipantRepository {
  @override
  Future<List<Participant>> getByGroupId(String groupId) async {
    final raw = await ConvexClient.instance.query('participants:listByGroup', {
      'groupId': groupId,
    });
    final list =
        jsonDecode(raw.isNotEmpty ? raw : '[]') as List<dynamic>? ?? [];
    return list
        .map((e) => _participantFromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Stream<List<Participant>> watchByGroupId(String groupId) {
    return _subscribeList('participants:listByGroup', {
      'groupId': groupId,
    }, _participantFromJson);
  }

  @override
  Future<Participant?> getById(String id) async {
    final raw = await ConvexClient.instance.query('participants:get', {
      'id': id,
    });
    if (raw.isEmpty) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>?;
    return map != null ? _participantFromJson(map) : null;
  }

  @override
  Future<String> create(String groupId, String name, int order) async {
    final raw = await ConvexClient.instance.mutation(
      name: 'participants:create',
      args: {'groupId': groupId, 'name': name, 'order': order},
    );
    return raw as String? ?? '';
  }

  @override
  Future<void> update(Participant participant) async {
    await ConvexClient.instance.mutation(
      name: 'participants:update',
      args: {
        'id': participant.id,
        'name': participant.name,
        'order': participant.order,
        'updatedAt': participant.updatedAt.millisecondsSinceEpoch,
      },
    );
  }

  @override
  Future<void> delete(String id) async {
    await ConvexClient.instance.mutation(
      name: 'participants:remove',
      args: {'id': id},
    );
  }

  Participant _participantFromJson(Map<String, dynamic> j) {
    return Participant(
      id: j['_id'] as String? ?? '',
      groupId: j['groupId'] as String? ?? '',
      name: j['name'] as String? ?? '',
      order: (j['order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (j['createdAt'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (j['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class ConvexExpenseRepository implements IExpenseRepository {
  @override
  Future<List<Expense>> getByGroupId(String groupId) async {
    final raw = await ConvexClient.instance.query('expenses:listByGroup', {
      'groupId': groupId,
    });
    final list =
        jsonDecode(raw.isNotEmpty ? raw : '[]') as List<dynamic>? ?? [];
    return list
        .map((e) => _expenseFromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Stream<List<Expense>> watchByGroupId(String groupId) {
    return _subscribeList('expenses:listByGroup', {
      'groupId': groupId,
    }, _expenseFromJson);
  }

  @override
  Future<Expense?> getById(String id) async {
    final raw = await ConvexClient.instance.query('expenses:get', {'id': id});
    if (raw.isEmpty) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>?;
    return map != null ? _expenseFromJson(map) : null;
  }

  @override
  Future<String> create(Expense expense) async {
    final args = <String, dynamic>{
      'groupId': expense.groupId,
      'payerParticipantId': expense.payerParticipantId,
      'amountCents': expense.amountCents,
      'currencyCode': expense.currencyCode,
      'title': expense.title,
      'date': expense.date.millisecondsSinceEpoch,
      'splitType': expense.splitType.name,
      'splitSharesJson': jsonEncode(expense.splitShares),
      'type': expense.transactionType.name,
    };
    if (expense.toParticipantId != null) {
      args['toParticipantId'] = expense.toParticipantId;
    }
    final raw = await ConvexClient.instance.mutation(
      name: 'expenses:create',
      args: args,
    );
    return raw as String? ?? '';
  }

  @override
  Future<void> update(Expense expense) async {
    await ConvexClient.instance.mutation(
      name: 'expenses:update',
      args: {
        'id': expense.id,
        'title': expense.title,
        'amountCents': expense.amountCents,
        'date': expense.date.millisecondsSinceEpoch,
        'splitSharesJson': jsonEncode(expense.splitShares),
        'updatedAt': expense.updatedAt.millisecondsSinceEpoch,
      },
    );
  }

  @override
  Future<void> delete(String id) async {
    await ConvexClient.instance.mutation(
      name: 'expenses:remove',
      args: {'id': id},
    );
  }

  Expense _expenseFromJson(Map<String, dynamic> j) {
    Map<String, int> splitShares = {};
    try {
      final s = j['splitSharesJson'] as String?;
      if (s != null && s.isNotEmpty) {
        final map = jsonDecode(s) as Map<String, dynamic>?;
        if (map != null) {
          splitShares = map.map((k, v) => MapEntry(k, (v as num).toInt()));
        }
      }
    } catch (e) {
      Log.debug('Convex expense splitShares parse failed: $e');
    }
    final typeStr = j['type'] as String?;
    final toId = j['toParticipantId'] as String?;
    final splitTypeStr = j['splitType'] as String?;
    final splitType = _parseSplitType(splitTypeStr);
    return Expense(
      id: j['_id'] as String? ?? '',
      groupId: j['groupId'] as String? ?? '',
      payerParticipantId: j['payerParticipantId'] as String? ?? '',
      amountCents: (j['amountCents'] as num?)?.toInt() ?? 0,
      currencyCode: j['currencyCode'] as String? ?? 'USD',
      title: j['title'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        (j['date'] as num?)?.toInt() ?? 0,
      ),
      splitType: splitType,
      splitShares: splitShares,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (j['createdAt'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (j['updatedAt'] as num?)?.toInt() ?? 0,
      ),
      transactionType: TransactionType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => TransactionType.expense,
      ),
      toParticipantId: toId,
    );
  }
}

Stream<List<T>> _subscribeList<T>(
  String name,
  Map<String, String> args,
  T Function(Map<String, dynamic>) fromJson,
) {
  final controller = StreamController<List<T>>.broadcast(sync: true);
  ConvexClient.instance
      .subscribe(
        name: name,
        args: args,
        onUpdate: (value) {
          try {
            final list =
                jsonDecode(value.isNotEmpty ? value : '[]') as List<dynamic>? ??
                [];
            controller.add(
              list.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
            );
          } catch (e, stackTrace) {
            Log.error('Convex subscribe onUpdate parse failed', error: e, stackTrace: stackTrace);
          }
        },
        onError: (error, stackTrace) {
          // Convex onError passes (Object?, String?) so we log error only
          Log.error('Convex subscribe onError', error: error);
        },
      )
      .then((sub) {
        controller.onCancel = () => sub.cancel();
      });
  return controller.stream;
}
