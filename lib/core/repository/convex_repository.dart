import 'dart:async';
import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import '../../domain/domain.dart';
import 'group_repository.dart';
import 'participant_repository.dart';
import 'expense_repository.dart';
import 'tag_repository.dart';

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
    try {
      final raw = await ConvexClient.instance.mutation(
        name: 'groups:create',
        args: {'name': name, 'currencyCode': currencyCode},
      );
      final id = raw as String? ?? '';
      Log.info('Group created: id=$id name="$name" currencyCode=$currencyCode');
      return id;
    } catch (e, st) {
      Log.error('Convex group create failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> update(Group group) async {
    try {
      final args = <String, dynamic>{
        'id': group.id,
        'name': group.name,
        'currencyCode': group.currencyCode,
        'updatedAt': group.updatedAt.millisecondsSinceEpoch,
        'settlementMethod': group.settlementMethod.name,
      };
      if (group.treasurerParticipantId != null) {
        args['treasurerParticipantId'] = group.treasurerParticipantId;
      }
      if (group.settlementFreezeAt != null) {
        args['settlementFreezeAt'] =
            group.settlementFreezeAt!.millisecondsSinceEpoch;
      }
      if (group.settlementSnapshotJson != null) {
        args['settlementSnapshotJson'] = group.settlementSnapshotJson;
      }
      await ConvexClient.instance.mutation(name: 'groups:update', args: args);
      Log.info('Group updated: id=${group.id} name="${group.name}"');
    } catch (e, st) {
      Log.error('Convex group update failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'groups:remove',
        args: {'id': id},
      );
      Log.info('Group deleted: id=$id');
    } catch (e, st) {
      Log.error('Convex group delete failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> freezeSettlement(
    String groupId,
    SettlementSnapshot snapshot,
  ) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'groups:freezeSettlement',
        args: {
          'id': groupId,
          'settlementSnapshotJson': snapshot.toJsonString(),
          'settlementFreezeAt': snapshot.frozenAt.millisecondsSinceEpoch,
        },
      );
      Log.info('Settlement frozen: groupId=$groupId');
    } catch (e, st) {
      Log.error('Convex freezeSettlement failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> unfreezeSettlement(String groupId) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'groups:unfreezeSettlement',
        args: {'id': groupId},
      );
      Log.info('Settlement unfrozen: groupId=$groupId');
    } catch (e, st) {
      Log.error('Convex unfreezeSettlement failed', error: e, stackTrace: st);
      rethrow;
    }
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
      settlementMethod: _parseSettlementMethod(
        j['settlementMethod'] as String?,
      ),
      treasurerParticipantId: j['treasurerParticipantId'] as String?,
      settlementFreezeAt: j['settlementFreezeAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (j['settlementFreezeAt'] as num).toInt(),
            )
          : null,
      settlementSnapshotJson: j['settlementSnapshotJson'] as String?,
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
    try {
      final raw = await ConvexClient.instance.mutation(
        name: 'participants:create',
        args: {'groupId': groupId, 'name': name, 'order': order},
      );
      final id = raw as String? ?? '';
      Log.info('Participant created: id=$id groupId=$groupId name="$name"');
      return id;
    } catch (e, st) {
      Log.error('Convex participant create failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> update(Participant participant) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'participants:update',
        args: {
          'id': participant.id,
          'name': participant.name,
          'order': participant.order,
          'updatedAt': participant.updatedAt.millisecondsSinceEpoch,
        },
      );
      Log.info(
        'Participant updated: id=${participant.id} name="${participant.name}"',
      );
    } catch (e, st) {
      Log.error('Convex participant update failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'participants:remove',
        args: {'id': id},
      );
      Log.info('Participant deleted: id=$id');
    } catch (e, st) {
      Log.error('Convex participant delete failed', error: e, stackTrace: st);
      rethrow;
    }
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
    try {
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
      if (expense.tag != null) {
        args['tag'] = expense.tag;
      }
      if (expense.description != null && expense.description!.isNotEmpty) {
        args['description'] = expense.description;
      }
      if (expense.lineItems != null && expense.lineItems!.isNotEmpty) {
        args['lineItemsJson'] = jsonEncode(
          expense.lineItems!.map((e) => e.toJson()).toList(),
        );
      }
      if (expense.receiptImagePath != null &&
          expense.receiptImagePath!.isNotEmpty) {
        args['receiptImagePath'] = expense.receiptImagePath;
      }
      final raw = await ConvexClient.instance.mutation(
        name: 'expenses:create',
        args: args,
      );
      final id = raw as String? ?? '';
      Log.info(
        'Expense created: id=$id groupId=${expense.groupId} title="${expense.title}" amountCents=${expense.amountCents} currencyCode=${expense.currencyCode}',
      );
      return id;
    } catch (e, st) {
      Log.error('Convex expense create failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> update(Expense expense) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'expenses:update',
        args: {
          'id': expense.id,
          'title': expense.title,
          'amountCents': expense.amountCents,
          'date': expense.date.millisecondsSinceEpoch,
          'splitSharesJson': jsonEncode(expense.splitShares),
          'updatedAt': expense.updatedAt.millisecondsSinceEpoch,
          'tag': expense.tag,
          'description': expense.description ?? '',
          'lineItemsJson':
              expense.lineItems == null || expense.lineItems!.isEmpty
              ? '[]'
              : jsonEncode(expense.lineItems!.map((e) => e.toJson()).toList()),
          'receiptImagePath': expense.receiptImagePath ?? '',
        },
      );
      Log.info(
        'Expense updated: id=${expense.id} title="${expense.title}" amountCents=${expense.amountCents}',
      );
    } catch (e, st) {
      Log.error('Convex expense update failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'expenses:remove',
        args: {'id': id},
      );
      Log.info('Expense deleted: id=$id');
    } catch (e, st) {
      Log.error('Convex expense delete failed', error: e, stackTrace: st);
      rethrow;
    }
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
    List<ReceiptLineItem>? lineItems;
    try {
      final lineJson = j['lineItemsJson'] as String?;
      if (lineJson != null && lineJson.isNotEmpty) {
        final list = jsonDecode(lineJson) as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          lineItems = list
              .map((e) => ReceiptLineItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      Log.debug('Convex expense lineItems parse failed: $e');
    }
    return Expense(
      id: j['_id'] as String? ?? '',
      groupId: j['groupId'] as String? ?? '',
      payerParticipantId: j['payerParticipantId'] as String? ?? '',
      amountCents: (j['amountCents'] as num?)?.toInt() ?? 0,
      currencyCode: j['currencyCode'] as String? ?? 'USD',
      title: j['title'] as String? ?? '',
      description: (j['description'] as String?)?.isEmpty ?? true
          ? null
          : j['description'] as String?,
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
      tag: j['tag'] as String?,
      lineItems: lineItems,
      receiptImagePath: (j['receiptImagePath'] as String?)?.isEmpty ?? true
          ? null
          : j['receiptImagePath'] as String?,
    );
  }
}

class ConvexTagRepository implements ITagRepository {
  @override
  Future<List<ExpenseTag>> getByGroupId(String groupId) async {
    final raw = await ConvexClient.instance.query('expense_tags:listByGroup', {
      'groupId': groupId,
    });
    final list =
        jsonDecode(raw.isNotEmpty ? raw : '[]') as List<dynamic>? ?? [];
    return list.map((e) => _tagFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<ExpenseTag>> watchByGroupId(String groupId) {
    return _subscribeList('expense_tags:listByGroup', {
      'groupId': groupId,
    }, _tagFromJson);
  }

  @override
  Future<ExpenseTag?> getById(String id) async {
    final raw = await ConvexClient.instance.query('expense_tags:get', {
      'id': id,
    });
    if (raw.isEmpty) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>?;
    return map != null ? _tagFromJson(map) : null;
  }

  @override
  Future<String> create(String groupId, String label, String iconName) async {
    final raw = await ConvexClient.instance.mutation(
      name: 'expense_tags:create',
      args: {'groupId': groupId, 'label': label, 'iconName': iconName},
    );
    return raw as String? ?? '';
  }

  @override
  Future<void> update(ExpenseTag tag) async {
    await ConvexClient.instance.mutation(
      name: 'expense_tags:update',
      args: {
        'id': tag.id,
        'label': tag.label,
        'iconName': tag.iconName,
        'updatedAt': tag.updatedAt.millisecondsSinceEpoch,
      },
    );
  }

  @override
  Future<void> delete(String id) async {
    await ConvexClient.instance.mutation(
      name: 'expense_tags:remove',
      args: {'id': id},
    );
  }

  ExpenseTag _tagFromJson(Map<String, dynamic> j) {
    return ExpenseTag(
      id: j['_id'] as String? ?? '',
      groupId: j['groupId'] as String? ?? '',
      label: j['label'] as String? ?? '',
      iconName: j['iconName'] as String? ?? 'label',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (j['createdAt'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (j['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

Stream<List<T>> _subscribeList<T>(
  String name,
  Map<String, String> args,
  T Function(Map<String, dynamic>) fromJson,
) {
  final controller = StreamController<List<T>>.broadcast(sync: true);
  var cancelled = false;
  dynamic convexSub;

  controller.onCancel = () {
    if (convexSub != null) {
      convexSub.cancel();
    } else {
      cancelled = true;
    }
  };

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
            Log.error(
              'Convex subscribe onUpdate parse failed',
              error: e,
              stackTrace: stackTrace,
            );
          }
        },
        onError: (error, stackTrace) {
          // Convex onError passes (Object?, String?) so we log error only
          Log.error('Convex subscribe onError', error: error);
        },
      )
      .then((sub) {
        convexSub = sub;
        if (cancelled) sub.cancel();
      });
  return controller.stream;
}
