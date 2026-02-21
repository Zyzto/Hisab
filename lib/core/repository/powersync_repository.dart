import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/domain.dart';
import 'group_repository.dart';
import 'participant_repository.dart';
import 'expense_repository.dart';
import 'tag_repository.dart';
import 'group_member_repository.dart';
import 'group_invite_repository.dart';

const _uuid = Uuid();

/// On web, PowerSync/sqlite3_web can emit raw JS objects (LegacyJavaScriptObject)
/// in update streams instead of Dart UpdateNotification, causing type errors.
/// Use polling instead of watch() to avoid the broken stream.
const _webPollPeriod = Duration(milliseconds: 800);

Stream<T> _pollStream<T>(Future<T> Function() fetch) async* {
  yield await fetch();
  await for (final _ in Stream.periodic(_webPollPeriod)) {
    yield await fetch();
  }
}

// =============================================================================
// Row parsing helpers
// =============================================================================

DateTime _parseDateTime(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString()) ?? DateTime.now();
}

DateTime? _parseDateTimeNullable(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

bool _parseBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is int) return v == 1;
  return v.toString() == 'true' || v.toString() == '1';
}

/// Convert an unsigned ARGB32 color int to a signed 32-bit int for Postgres.
int? _colorToSigned(int? color) {
  if (color == null) return null;
  // If the value exceeds signed 32-bit max, convert to signed representation.
  if (color > 0x7FFFFFFF) return color - 0x100000000;
  return color;
}

/// Convert a signed 32-bit int from Postgres back to an unsigned ARGB32 color.
int? _colorToUnsigned(int? color) {
  if (color == null) return null;
  if (color < 0) return color + 0x100000000;
  return color;
}

SettlementMethod _parseSettlementMethod(dynamic v) {
  if (v == null) return SettlementMethod.greedy;
  switch (v.toString()) {
    case 'pairwise':
      return SettlementMethod.pairwise;
    case 'consolidated':
      return SettlementMethod.consolidated;
    case 'treasurer':
      return SettlementMethod.treasurer;
    default:
      return SettlementMethod.greedy;
  }
}

SplitType _parseSplitType(dynamic v) {
  switch (v?.toString()) {
    case 'parts':
      return SplitType.parts;
    case 'amounts':
      return SplitType.amounts;
    default:
      return SplitType.equal;
  }
}

TransactionType _parseTransactionType(dynamic v) {
  switch (v?.toString()) {
    case 'income':
      return TransactionType.income;
    case 'transfer':
      return TransactionType.transfer;
    default:
      return TransactionType.expense;
  }
}

Map<String, int> _parseSplitShares(dynamic v) {
  if (v == null || v.toString().isEmpty) return {};
  try {
    final decoded = jsonDecode(v.toString());
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
  } catch (_) {}
  return {};
}

List<ReceiptLineItem>? _parseLineItems(dynamic v) {
  if (v == null || v.toString().isEmpty) return null;
  try {
    final decoded = jsonDecode(v.toString());
    if (decoded is List) {
      return decoded
          .map((e) => ReceiptLineItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  } catch (_) {}
  return null;
}

Group _groupFromRow(Map<String, dynamic> row) => Group(
  id: row['id'] as String,
  name: row['name'] as String? ?? '',
  currencyCode: row['currency_code'] as String? ?? 'USD',
  createdAt: _parseDateTime(row['created_at']),
  updatedAt: _parseDateTime(row['updated_at']),
  settlementMethod: _parseSettlementMethod(row['settlement_method']),
  treasurerParticipantId: row['treasurer_participant_id'] as String?,
  settlementFreezeAt: _parseDateTimeNullable(row['settlement_freeze_at']),
  settlementSnapshotJson: row['settlement_snapshot_json'] as String?,
  ownerId: row['owner_id'] as String?,
  allowMemberAddExpense: _parseBool(row['allow_member_add_expense']),
  allowMemberChangeSettings: _parseBool(row['allow_member_change_settings']),
  icon: row['icon'] as String?,
  color: _colorToUnsigned((row['color'] as num?)?.toInt()),
  archivedAt: _parseDateTimeNullable(row['archived_at']),
);

Participant _participantFromRow(Map<String, dynamic> row) => Participant(
  id: row['id'] as String,
  groupId: row['group_id'] as String,
  name: row['name'] as String? ?? '',
  order: (row['sort_order'] as num?)?.toInt() ?? 0,
  userId: row['user_id'] as String?,
  avatarId: row['avatar_id'] as String?,
  createdAt: _parseDateTime(row['created_at']),
  updatedAt: _parseDateTime(row['updated_at']),
);

Expense _expenseFromRow(Map<String, dynamic> row) => Expense(
  id: row['id'] as String,
  groupId: row['group_id'] as String,
  payerParticipantId: row['payer_participant_id'] as String,
  amountCents: (row['amount_cents'] as num).toInt(),
  currencyCode: row['currency_code'] as String? ?? 'USD',
  exchangeRate: (row['exchange_rate'] as num?)?.toDouble() ?? 1.0,
  baseAmountCents: (row['base_amount_cents'] as num?)?.toInt(),
  title: row['title'] as String? ?? '',
  description: row['description'] as String?,
  date: _parseDateTime(row['date']),
  splitType: _parseSplitType(row['split_type']),
  splitShares: _parseSplitShares(row['split_shares_json']),
  createdAt: _parseDateTime(row['created_at']),
  updatedAt: _parseDateTime(row['updated_at']),
  transactionType: _parseTransactionType(row['type']),
  toParticipantId: row['to_participant_id'] as String?,
  tag: row['tag'] as String?,
  lineItems: _parseLineItems(row['line_items_json']),
  receiptImagePath: row['receipt_image_path'] as String?,
);

ExpenseTag _tagFromRow(Map<String, dynamic> row) => ExpenseTag(
  id: row['id'] as String,
  groupId: row['group_id'] as String,
  label: row['label'] as String? ?? '',
  iconName: row['icon_name'] as String? ?? 'label',
  createdAt: _parseDateTime(row['created_at']),
  updatedAt: _parseDateTime(row['updated_at']),
);

GroupMember _memberFromRow(Map<String, dynamic> row) => GroupMember(
  id: row['id'] as String,
  groupId: row['group_id'] as String,
  userId: row['user_id'] as String,
  role: row['role'] as String? ?? 'member',
  participantId: row['participant_id'] as String?,
  joinedAt: _parseDateTime(row['joined_at']),
);

GroupInvite _inviteFromRow(Map<String, dynamic> row) => GroupInvite(
  id: row['id'] as String,
  groupId: row['group_id'] as String,
  token: row['token'] as String,
  inviteeEmail: row['invitee_email'] as String?,
  role: row['role'] as String? ?? 'member',
  createdAt: _parseDateTime(row['created_at']),
  expiresAt: _parseDateTimeNullable(row['expires_at']),
  createdBy: row['created_by'] as String?,
  label: row['label'] as String?,
  maxUses: (row['max_uses'] as num?)?.toInt(),
  useCount: (row['use_count'] as num?)?.toInt() ?? 0,
  isActive: _parseBool(row['is_active']),
);

InviteUsage _inviteUsageFromRow(Map<String, dynamic> row) => InviteUsage(
  id: row['id'] as String,
  inviteId: row['invite_id'] as String,
  userId: row['user_id'] as String,
  acceptedAt: _parseDateTime(row['accepted_at']),
);

String _nowIso() => DateTime.now().toUtc().toIso8601String();

/// Enqueue an offline write for later push.
Future<void> _enqueue(
  PowerSyncDatabase db, {
  required String tableName,
  required String operation,
  required String rowId,
  Map<String, dynamic>? data,
}) async {
  final id = _uuid.v4();
  await db.execute(
    'INSERT INTO pending_writes (id, table_name, operation, row_id, data_json, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    [
      id,
      tableName,
      operation,
      rowId,
      data != null ? jsonEncode(data) : null,
      _nowIso(),
    ],
  );
  Log.debug('Queued pending write: $operation on $tableName/$rowId');
}

// =============================================================================
// PowerSync Group Repository
// =============================================================================

class PowerSyncGroupRepository implements IGroupRepository {
  final PowerSyncDatabase _db;
  final SupabaseClient? _client;
  final bool _isOnline;
  final bool _isLocalOnly;

  PowerSyncGroupRepository(
    this._db, {
    SupabaseClient? client,
    bool isOnline = false,
    bool isLocalOnly = true,
  }) : _client = client,
       _isOnline = isOnline,
       _isLocalOnly = isLocalOnly;

  static const _activeGroupsWhere =
      "(archived_at IS NULL OR archived_at = '')";
  static const _archivedGroupsWhere =
      "archived_at IS NOT NULL AND archived_at != ''";

  @override
  Future<List<Group>> getAll() async {
    final rows = await _db.getAll(
      'SELECT * FROM groups WHERE $_activeGroupsWhere ORDER BY updated_at DESC',
    );
    return rows.map(_groupFromRow).toList();
  }

  @override
  Stream<List<Group>> watchAll() {
    if (kIsWeb) {
      return _pollStream(() async {
        final rows = await _db.getAll(
            'SELECT * FROM groups WHERE $_activeGroupsWhere ORDER BY updated_at DESC');
        return rows.map(_groupFromRow).toList();
      });
    }
    return _db
        .watch(
            'SELECT * FROM groups WHERE $_activeGroupsWhere ORDER BY updated_at DESC')
        .map((rows) => rows.map(_groupFromRow).toList());
  }

  @override
  Stream<List<Group>> watchArchived() {
    if (kIsWeb) {
      return _pollStream(() async {
        final rows = await _db.getAll(
            'SELECT * FROM groups WHERE $_archivedGroupsWhere ORDER BY updated_at DESC');
        return rows.map(_groupFromRow).toList();
      });
    }
    return _db
        .watch(
            'SELECT * FROM groups WHERE $_archivedGroupsWhere ORDER BY updated_at DESC')
        .map((rows) => rows.map(_groupFromRow).toList());
  }

  @override
  Future<Group?> getById(String id) async {
    final rows = await _db.getAll('SELECT * FROM groups WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _groupFromRow(rows.first);
  }

  @override
  Future<String> create(String name, String currencyCode, {String? icon, int? color, List<String> initialParticipants = const []}) async {
    final id = _uuid.v4();
    final now = _nowIso();
    String? ownerId;
    String? ownerDisplayName;
    String? ownerAvatarId;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      ownerId = user?.id;
      ownerDisplayName =
          user?.userMetadata?['display_name'] as String? ??
          user?.userMetadata?['full_name'] as String? ??
          user?.email ??
          'Owner';
      ownerAvatarId = user?.userMetadata?['avatar_id'] as String?;
    } catch (_) {}

    final groupData = <String, dynamic>{
      'id': id,
      'name': name,
      'currency_code': currencyCode,
      'owner_id': ownerId,
      'icon': icon,
      'color': _colorToSigned(color),
      'created_at': now,
      'updated_at': now,
    };

    // Auto-create a participant for the owner
    final participantId = _uuid.v4();
    final participantName = ownerDisplayName ?? 'Owner';

    if (!_isLocalOnly && _isOnline && _client != null) {
      // Online: write to Supabase first
      await _client.from('groups').insert(groupData);
      // Create owner membership first (without participant_id) so that
      // get_user_role() returns 'owner' for subsequent RLS checks.
      String? memberId;
      if (ownerId != null) {
        memberId = _uuid.v4();
        await _client.from('group_members').insert({
          'id': memberId,
          'group_id': id,
          'user_id': ownerId,
          'role': 'owner',
          'joined_at': now,
        });
      }
      // Create participant for owner (RLS now passes via get_user_role)
      await _client.from('participants').insert({
        'id': participantId,
        'group_id': id,
        'name': participantName,
        'sort_order': 0,
        'user_id': ownerId,
        'avatar_id': ownerAvatarId,
        'created_at': now,
        'updated_at': now,
      });
      // Link participant to the membership record
      if (memberId != null) {
        await _client
            .from('group_members')
            .update({'participant_id': participantId})
            .eq('id', memberId);
      }
      // Create additional participants from the wizard
      for (int i = 0; i < initialParticipants.length; i++) {
        final pName = initialParticipants[i].trim();
        if (pName.isEmpty) continue;
        final pId = _uuid.v4();
        await _client.from('participants').insert({
          'id': pId,
          'group_id': id,
          'name': pName,
          'sort_order': i + 1,
          'created_at': now,
          'updated_at': now,
        });
      }
    }

    // Always write to local DB
    await _db.execute(
      'INSERT INTO groups (id, name, currency_code, owner_id, icon, color, archived_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, name, currencyCode, ownerId, icon, color, null, now, now],
    );
    // Local participant for owner
    await _db.execute(
      'INSERT INTO participants (id, group_id, name, sort_order, user_id, avatar_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [participantId, id, participantName, 0, ownerId, ownerAvatarId, now, now],
    );
    if (ownerId != null) {
      final memberId = _uuid.v4();
      await _db.execute(
        'INSERT INTO group_members (id, group_id, user_id, role, participant_id, joined_at) VALUES (?, ?, ?, ?, ?, ?)',
        [memberId, id, ownerId, 'owner', participantId, now],
      );
    }
    // Create additional participants from the wizard in local DB
    for (int i = 0; i < initialParticipants.length; i++) {
      final pName = initialParticipants[i].trim();
      if (pName.isEmpty) continue;
      final pId = _uuid.v4();
      await _db.execute(
        'INSERT INTO participants (id, group_id, name, sort_order, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        [pId, id, pName, i + 1, now, now],
      );
    }

    Log.debug('Group created: $id');
    return id;
  }

  @override
  Future<void> update(Group group) async {
    final now = _nowIso();
    final data = <String, dynamic>{
      'id': group.id,
      'name': group.name,
      'currency_code': group.currencyCode,
      'settlement_method': group.settlementMethod.name,
      'treasurer_participant_id': group.treasurerParticipantId,
      'settlement_freeze_at': group.settlementFreezeAt
          ?.toUtc()
          .toIso8601String(),
      'settlement_snapshot_json': group.settlementSnapshotJson,
      'allow_member_add_expense': group.allowMemberAddExpense,
      'allow_member_change_settings': group.allowMemberChangeSettings,
      'icon': group.icon,
      'color': _colorToSigned(group.color),
      'archived_at': group.archivedAt?.toUtc().toIso8601String(),
      'updated_at': now,
    };

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.from('groups').update(data).eq('id', group.id);
    }

    await _db.execute(
      '''UPDATE groups SET
        name = ?, currency_code = ?, settlement_method = ?,
        treasurer_participant_id = ?, settlement_freeze_at = ?,
        settlement_snapshot_json = ?, allow_member_add_expense = ?,
        allow_member_change_settings = ?, icon = ?, color = ?,
        archived_at = ?, updated_at = ?
      WHERE id = ?''',
      [
        group.name,
        group.currencyCode,
        group.settlementMethod.name,
        group.treasurerParticipantId,
        group.settlementFreezeAt?.toUtc().toIso8601String(),
        group.settlementSnapshotJson,
        group.allowMemberAddExpense ? 1 : 0,
        group.allowMemberChangeSettings ? 1 : 0,
        group.icon,
        _colorToSigned(group.color),
        group.archivedAt?.toUtc().toIso8601String(),
        now,
        group.id,
      ],
    );
  }

  @override
  Future<void> archive(String groupId) async {
    final now = _nowIso();
    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client
          .from('groups')
          .update({'archived_at': now, 'updated_at': now})
          .eq('id', groupId);
    }
    await _db.execute(
      'UPDATE groups SET archived_at = ?, updated_at = ? WHERE id = ?',
      [now, now, groupId],
    );
  }

  @override
  Future<void> unarchive(String groupId) async {
    final now = _nowIso();
    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client
          .from('groups')
          .update({'archived_at': null, 'updated_at': now})
          .eq('id', groupId);
    }
    await _db.execute(
      'UPDATE groups SET archived_at = NULL, updated_at = ? WHERE id = ?',
      [now, groupId],
    );
  }

  @override
  Future<void> delete(String id) async {
    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.from('groups').delete().eq('id', id);
    }
    await _db.execute('DELETE FROM groups WHERE id = ?', [id]);
  }

  @override
  Future<void> freezeSettlement(
    String groupId,
    SettlementSnapshot snapshot,
  ) async {
    final now = _nowIso();
    final snapshotJson = snapshot.toJsonString();

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client
          .from('groups')
          .update({
            'settlement_freeze_at': now,
            'settlement_snapshot_json': snapshotJson,
            'updated_at': now,
          })
          .eq('id', groupId);
    }

    await _db.execute(
      'UPDATE groups SET settlement_freeze_at = ?, settlement_snapshot_json = ?, updated_at = ? WHERE id = ?',
      [now, snapshotJson, now, groupId],
    );
  }

  @override
  Future<void> unfreezeSettlement(String groupId) async {
    final now = _nowIso();

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client
          .from('groups')
          .update({
            'settlement_freeze_at': null,
            'settlement_snapshot_json': null,
            'updated_at': now,
          })
          .eq('id', groupId);
    }

    await _db.execute(
      'UPDATE groups SET settlement_freeze_at = NULL, settlement_snapshot_json = NULL, updated_at = ? WHERE id = ?',
      [now, groupId],
    );
  }
}

// =============================================================================
// PowerSync Participant Repository
// =============================================================================

class PowerSyncParticipantRepository implements IParticipantRepository {
  final PowerSyncDatabase _db;
  final SupabaseClient? _client;
  final bool _isOnline;
  final bool _isLocalOnly;

  PowerSyncParticipantRepository(
    this._db, {
    SupabaseClient? client,
    bool isOnline = false,
    bool isLocalOnly = true,
  }) : _client = client,
       _isOnline = isOnline,
       _isLocalOnly = isLocalOnly;

  @override
  Future<List<Participant>> getByGroupId(String groupId) async {
    final rows = await _db.getAll(
      'SELECT * FROM participants WHERE group_id = ? ORDER BY sort_order ASC',
      [groupId],
    );
    return rows.map(_participantFromRow).toList();
  }

  @override
  Stream<List<Participant>> watchByGroupId(String groupId) {
    if (kIsWeb) {
      return _pollStream(() => getByGroupId(groupId));
    }
    return _db
        .watch(
          'SELECT * FROM participants WHERE group_id = ? ORDER BY sort_order ASC',
          parameters: [groupId],
        )
        .map((rows) => rows.map(_participantFromRow).toList());
  }

  @override
  Future<Participant?> getById(String id) async {
    final rows = await _db.getAll('SELECT * FROM participants WHERE id = ?', [
      id,
    ]);
    if (rows.isEmpty) return null;
    return _participantFromRow(rows.first);
  }

  @override
  Future<String> create(String groupId, String name, int order, {String? userId, String? avatarId}) async {
    final id = _uuid.v4();
    final now = _nowIso();
    final data = <String, dynamic>{
      'id': id,
      'group_id': groupId,
      'name': name,
      'sort_order': order,
      'user_id': userId,
      'avatar_id': avatarId,
      'created_at': now,
      'updated_at': now,
    };

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.from('participants').insert(data);
    }

    await _db.execute(
      'INSERT INTO participants (id, group_id, name, sort_order, user_id, avatar_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [id, groupId, name, order, userId, avatarId, now, now],
    );
    return id;
  }

  @override
  Future<void> update(Participant participant) async {
    final now = _nowIso();

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client
          .from('participants')
          .update({
            'name': participant.name,
            'sort_order': participant.order,
            'avatar_id': participant.avatarId,
            'updated_at': now,
          })
          .eq('id', participant.id);
    }

    await _db.execute(
      'UPDATE participants SET name = ?, sort_order = ?, avatar_id = ?, updated_at = ? WHERE id = ?',
      [participant.name, participant.order, participant.avatarId, now, participant.id],
    );
  }

  @override
  Future<void> updateProfileByUserId(String userId, String newName, {String? avatarId}) async {
    final now = _nowIso();
    final updates = <String, dynamic>{
      'name': newName,
      'updated_at': now,
    };
    if (avatarId != null) updates['avatar_id'] = avatarId;

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client
          .from('participants')
          .update(updates)
          .eq('user_id', userId);
    }

    if (avatarId != null) {
      await _db.execute(
        'UPDATE participants SET name = ?, avatar_id = ?, updated_at = ? WHERE user_id = ?',
        [newName, avatarId, now, userId],
      );
    } else {
      await _db.execute(
        'UPDATE participants SET name = ?, updated_at = ? WHERE user_id = ?',
        [newName, now, userId],
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.from('participants').delete().eq('id', id);
    }
    await _db.execute('DELETE FROM participants WHERE id = ?', [id]);
  }
}

// =============================================================================
// PowerSync Expense Repository
// =============================================================================

class PowerSyncExpenseRepository implements IExpenseRepository {
  final PowerSyncDatabase _db;
  final SupabaseClient? _client;
  final bool _isOnline;
  final bool _isLocalOnly;

  PowerSyncExpenseRepository(
    this._db, {
    SupabaseClient? client,
    bool isOnline = false,
    bool isLocalOnly = true,
  }) : _client = client,
       _isOnline = isOnline,
       _isLocalOnly = isLocalOnly;

  @override
  Future<List<Expense>> getByGroupId(String groupId) async {
    final rows = await _db.getAll(
      'SELECT * FROM expenses WHERE group_id = ? ORDER BY date DESC',
      [groupId],
    );
    return rows.map(_expenseFromRow).toList();
  }

  @override
  Stream<List<Expense>> watchByGroupId(String groupId) {
    if (kIsWeb) {
      return _pollStream(() => getByGroupId(groupId));
    }
    return _db
        .watch(
          'SELECT * FROM expenses WHERE group_id = ? ORDER BY date DESC',
          parameters: [groupId],
        )
        .map((rows) => rows.map(_expenseFromRow).toList());
  }

  @override
  Future<Expense?> getById(String id) async {
    final rows = await _db.getAll('SELECT * FROM expenses WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _expenseFromRow(rows.first);
  }

  @override
  Future<String> create(Expense expense) async {
    final id = _uuid.v4();
    final now = _nowIso();
    final splitSharesJson = jsonEncode(expense.splitShares);
    final lineItemsJson = expense.lineItems != null
        ? jsonEncode(expense.lineItems!.map((e) => e.toJson()).toList())
        : null;

    final data = <String, dynamic>{
      'id': id,
      'group_id': expense.groupId,
      'payer_participant_id': expense.payerParticipantId,
      'amount_cents': expense.amountCents,
      'currency_code': expense.currencyCode,
      'exchange_rate': expense.exchangeRate,
      'base_amount_cents': expense.baseAmountCents,
      'title': expense.title,
      'description': expense.description,
      'date': expense.date.toUtc().toIso8601String(),
      'split_type': expense.splitType.name,
      'split_shares_json': splitSharesJson,
      'type': expense.transactionType.name,
      'to_participant_id': expense.toParticipantId,
      'tag': expense.tag,
      'line_items_json': lineItemsJson,
      'receipt_image_path': expense.receiptImagePath,
      'created_at': now,
      'updated_at': now,
    };

    if (!_isLocalOnly && _isOnline && _client != null) {
      // Online: write to Supabase first
      await _client.from('expenses').insert(data);
    } else if (!_isLocalOnly && !_isOnline) {
      // Online mode but temporarily offline: queue for later push
      await _enqueue(
        _db,
        tableName: 'expenses',
        operation: 'insert',
        rowId: id,
        data: data,
      );
    }

    // Always write to local DB
    await _db.execute(
      '''INSERT INTO expenses (id, group_id, payer_participant_id, amount_cents,
        currency_code, exchange_rate, base_amount_cents,
        title, description, date, split_type, split_shares_json,
        type, to_participant_id, tag, line_items_json, receipt_image_path,
        created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        id,
        expense.groupId,
        expense.payerParticipantId,
        expense.amountCents,
        expense.currencyCode,
        expense.exchangeRate,
        expense.baseAmountCents,
        expense.title,
        expense.description,
        expense.date.toUtc().toIso8601String(),
        expense.splitType.name,
        splitSharesJson,
        expense.transactionType.name,
        expense.toParticipantId,
        expense.tag,
        lineItemsJson,
        expense.receiptImagePath,
        now,
        now,
      ],
    );
    return id;
  }

  @override
  Future<void> update(Expense expense) async {
    final now = _nowIso();
    final splitSharesJson = jsonEncode(expense.splitShares);
    final lineItemsJson = expense.lineItems != null
        ? jsonEncode(expense.lineItems!.map((e) => e.toJson()).toList())
        : null;

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client
          .from('expenses')
          .update({
            'title': expense.title,
            'amount_cents': expense.amountCents,
            'currency_code': expense.currencyCode,
            'exchange_rate': expense.exchangeRate,
            'base_amount_cents': expense.baseAmountCents,
            'payer_participant_id': expense.payerParticipantId,
            'description': expense.description,
            'date': expense.date.toUtc().toIso8601String(),
            'split_type': expense.splitType.name,
            'split_shares_json': splitSharesJson,
            'type': expense.transactionType.name,
            'to_participant_id': expense.toParticipantId,
            'tag': expense.tag,
            'line_items_json': lineItemsJson,
            'receipt_image_path': expense.receiptImagePath,
            'updated_at': now,
          })
          .eq('id', expense.id);
    }

    await _db.execute(
      '''UPDATE expenses SET
        title = ?, amount_cents = ?, currency_code = ?,
        exchange_rate = ?, base_amount_cents = ?,
        payer_participant_id = ?,
        description = ?, date = ?, split_type = ?, split_shares_json = ?,
        type = ?, to_participant_id = ?, tag = ?,
        line_items_json = ?, receipt_image_path = ?, updated_at = ?
      WHERE id = ?''',
      [
        expense.title,
        expense.amountCents,
        expense.currencyCode,
        expense.exchangeRate,
        expense.baseAmountCents,
        expense.payerParticipantId,
        expense.description,
        expense.date.toUtc().toIso8601String(),
        expense.splitType.name,
        splitSharesJson,
        expense.transactionType.name,
        expense.toParticipantId,
        expense.tag,
        lineItemsJson,
        expense.receiptImagePath,
        now,
        expense.id,
      ],
    );
  }

  @override
  Future<void> delete(String id) async {
    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.from('expenses').delete().eq('id', id);
    }
    await _db.execute('DELETE FROM expenses WHERE id = ?', [id]);
  }
}

// =============================================================================
// PowerSync Tag Repository
// =============================================================================

class PowerSyncTagRepository implements ITagRepository {
  final PowerSyncDatabase _db;
  final SupabaseClient? _client;
  final bool _isOnline;
  final bool _isLocalOnly;

  PowerSyncTagRepository(
    this._db, {
    SupabaseClient? client,
    bool isOnline = false,
    bool isLocalOnly = true,
  }) : _client = client,
       _isOnline = isOnline,
       _isLocalOnly = isLocalOnly;

  @override
  Future<List<ExpenseTag>> getByGroupId(String groupId) async {
    final rows = await _db.getAll(
      'SELECT * FROM expense_tags WHERE group_id = ? ORDER BY label ASC',
      [groupId],
    );
    return rows.map(_tagFromRow).toList();
  }

  @override
  Stream<List<ExpenseTag>> watchByGroupId(String groupId) {
    if (kIsWeb) {
      return _pollStream(() => getByGroupId(groupId));
    }
    return _db
        .watch(
          'SELECT * FROM expense_tags WHERE group_id = ? ORDER BY label ASC',
          parameters: [groupId],
        )
        .map((rows) => rows.map(_tagFromRow).toList());
  }

  @override
  Future<ExpenseTag?> getById(String id) async {
    final rows = await _db.getAll('SELECT * FROM expense_tags WHERE id = ?', [
      id,
    ]);
    if (rows.isEmpty) return null;
    return _tagFromRow(rows.first);
  }

  @override
  Future<String> create(String groupId, String label, String iconName) async {
    final id = _uuid.v4();
    final now = _nowIso();
    final data = <String, dynamic>{
      'id': id,
      'group_id': groupId,
      'label': label,
      'icon_name': iconName,
      'created_at': now,
      'updated_at': now,
    };

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.from('expense_tags').insert(data);
    }

    await _db.execute(
      'INSERT INTO expense_tags (id, group_id, label, icon_name, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
      [id, groupId, label, iconName, now, now],
    );
    return id;
  }

  @override
  Future<void> update(ExpenseTag tag) async {
    final now = _nowIso();

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client
          .from('expense_tags')
          .update({
            'label': tag.label,
            'icon_name': tag.iconName,
            'updated_at': now,
          })
          .eq('id', tag.id);
    }

    await _db.execute(
      'UPDATE expense_tags SET label = ?, icon_name = ?, updated_at = ? WHERE id = ?',
      [tag.label, tag.iconName, now, tag.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.from('expense_tags').delete().eq('id', id);
    }
    await _db.execute('DELETE FROM expense_tags WHERE id = ?', [id]);
  }
}

// =============================================================================
// PowerSync GroupMember Repository
// =============================================================================

class PowerSyncGroupMemberRepository implements IGroupMemberRepository {
  final PowerSyncDatabase _db;
  final bool isLocalOnly;
  PowerSyncGroupMemberRepository(this._db, {this.isLocalOnly = false});

  String? get _currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient? get _supabase {
    if (isLocalOnly) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<GroupRole?> getMyRole(String groupId) async {
    final userId = _currentUserId;
    if (userId == null) return null;
    final rows = await _db.getAll(
      'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
      [groupId, userId],
    );
    if (rows.isEmpty) return null;
    return GroupRole.fromString(rows.first['role'] as String?);
  }

  @override
  Future<GroupMember?> getMyMember(String groupId) async {
    final userId = _currentUserId;
    if (userId == null) return null;
    final rows = await _db.getAll(
      'SELECT * FROM group_members WHERE group_id = ? AND user_id = ?',
      [groupId, userId],
    );
    if (rows.isEmpty) return null;
    return _memberFromRow(rows.first);
  }

  @override
  Future<List<GroupMember>> listByGroup(String groupId) async {
    final rows = await _db.getAll(
      'SELECT * FROM group_members WHERE group_id = ? ORDER BY joined_at ASC',
      [groupId],
    );
    return rows.map(_memberFromRow).toList();
  }

  @override
  Stream<List<GroupMember>> watchByGroup(String groupId) {
    if (kIsWeb) {
      return _pollStream(() => listByGroup(groupId));
    }
    return _db
        .watch(
          'SELECT * FROM group_members WHERE group_id = ? ORDER BY joined_at ASC',
          parameters: [groupId],
        )
        .map((rows) => rows.map(_memberFromRow).toList());
  }

  @override
  Future<void> kickMember(String groupId, String memberId) async {
    final client = _supabase;
    if (client != null) {
      await client.rpc(
        'kick_member',
        params: {'p_group_id': groupId, 'p_member_id': memberId},
      );
      Log.info('Member kicked via RPC');
    } else {
      throw UnsupportedError('kickMember requires online mode');
    }
  }

  @override
  Future<void> leave(String groupId) async {
    final client = _supabase;
    if (client != null) {
      await client.rpc('leave_group', params: {'p_group_id': groupId});
      Log.info('Left group via RPC');
    } else {
      throw UnsupportedError('leave requires online mode');
    }
  }

  @override
  Future<void> updateRole(
    String groupId,
    String memberId,
    GroupRole role,
  ) async {
    final client = _supabase;
    if (client != null) {
      await client.rpc(
        'update_member_role',
        params: {
          'p_group_id': groupId,
          'p_member_id': memberId,
          'p_role': role.name,
        },
      );
      Log.info('Member role updated via RPC');
    } else {
      throw UnsupportedError('updateRole requires online mode');
    }
  }

  @override
  Future<void> transferOwnership(
    String groupId,
    String newOwnerMemberId,
  ) async {
    final client = _supabase;
    if (client != null) {
      await client.rpc(
        'transfer_ownership',
        params: {
          'p_group_id': groupId,
          'p_new_owner_member_id': newOwnerMemberId,
        },
      );
      Log.info('Ownership transferred via RPC');
    } else {
      throw UnsupportedError('transferOwnership requires online mode');
    }
  }

}

// =============================================================================
// PowerSync GroupInvite Repository
// =============================================================================

class PowerSyncGroupInviteRepository implements IGroupInviteRepository {
  final PowerSyncDatabase _db;
  final SupabaseClient? supabaseClient;
  PowerSyncGroupInviteRepository(this._db, {this.supabaseClient});

  @override
  Future<({GroupInvite invite, Group group})?> getByToken(String token) async {
    final client = supabaseClient;
    if (client == null) {
      throw UnsupportedError('getByToken requires online mode');
    }
    final result = await client.rpc(
      'get_invite_by_token',
      params: {'p_token': token},
    );
    if (result == null || (result is List && result.isEmpty)) return null;
    final row = result is List ? result.first : result;

    final invite = GroupInvite(
      id: row['invite_id'] as String,
      groupId: row['group_id'] as String,
      token: row['token'] as String,
      inviteeEmail: row['invitee_email'] as String?,
      role: row['role'] as String? ?? 'member',
      createdAt: _parseDateTime(row['created_at']),
      expiresAt: _parseDateTimeNullable(row['expires_at']),
    );
    final group = Group(
      id: row['group_id'] as String,
      name: row['group_name'] as String? ?? '',
      currencyCode: row['group_currency_code'] as String? ?? 'USD',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return (invite: invite, group: group);
  }

  @override
  Future<({String id, String token})> createInvite(
    String groupId, {
    String? inviteeEmail,
    String? role,
    String? label,
    int? maxUses,
    Duration? expiresIn,
  }) async {
    final client = supabaseClient;
    if (client == null) {
      throw UnsupportedError('createInvite requires online mode');
    }
    final effectiveRole = role ?? 'member';
    final params = <String, dynamic>{
      'p_group_id': groupId,
      'p_invitee_email': inviteeEmail,
      'p_role': effectiveRole,
      'p_label': label,
      'p_max_uses': maxUses,
    };
    // Convert Duration to PostgreSQL interval string, or null for never
    if (expiresIn == null) {
      params['p_expires_in'] = null;
    } else {
      final totalSeconds = expiresIn.inSeconds;
      params['p_expires_in'] = '$totalSeconds seconds';
    }
    final result = await client.rpc('create_invite', params: params);
    final row = result is List ? result.first : result;
    final id = row['id'] as String;
    final token = row['token'] as String;

    // Insert into local DB so watchers update immediately
    final now = _nowIso();
    final expiresAtIso = expiresIn != null
        ? DateTime.now().toUtc().add(expiresIn).toIso8601String()
        : null;
    final createdBy = client.auth.currentUser?.id;
    await _db.execute(
      '''INSERT OR REPLACE INTO group_invites
        (id, group_id, token, invitee_email, role, created_at, expires_at,
         created_by, label, max_uses, use_count, is_active)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1)''',
      [
        id, groupId, token, inviteeEmail, effectiveRole, now, expiresAtIso,
        createdBy, label, maxUses,
      ],
    );

    return (id: id, token: token);
  }

  @override
  Future<String> accept(String token) async {
    final client = supabaseClient;
    if (client == null) {
      throw UnsupportedError('accept requires online mode');
    }
    final result = await client.rpc(
      'accept_invite',
      params: {
        'p_token': token,
        'p_participant_id': null,
        'p_new_participant_name': null,
      },
    );
    Log.info('Invite accepted');
    return result as String;
  }

  @override
  Future<List<GroupInvite>> listByGroup(String groupId) async {
    final rows = await _db.getAll(
      'SELECT * FROM group_invites WHERE group_id = ?',
      [groupId],
    );
    return rows.map(_inviteFromRow).toList();
  }

  @override
  Stream<List<GroupInvite>> watchByGroup(String groupId) {
    if (kIsWeb) {
      return _pollStream(() => listByGroup(groupId));
    }
    return _db
        .watch(
          'SELECT * FROM group_invites WHERE group_id = ?',
          parameters: [groupId],
        )
        .map((rows) => rows.map(_inviteFromRow).toList());
  }

  @override
  Future<void> revoke(String inviteId) async {
    final client = supabaseClient;
    if (client != null) {
      await client.rpc('revoke_invite', params: {'p_invite_id': inviteId});
    }
    // Always update local DB so watchers fire immediately
    await _db.execute(
      'UPDATE group_invites SET is_active = 0 WHERE id = ?',
      [inviteId],
    );
  }

  @override
  Future<void> toggleActive(String inviteId, bool active) async {
    final client = supabaseClient;
    if (client != null) {
      await client.rpc('toggle_invite_active', params: {
        'p_invite_id': inviteId,
        'p_active': active,
      });
    }
    // Always update local DB so watchers fire immediately
    await _db.execute(
      'UPDATE group_invites SET is_active = ? WHERE id = ?',
      [active ? 1 : 0, inviteId],
    );
  }

  @override
  Future<List<InviteUsage>> listUsages(String inviteId) async {
    final rows = await _db.getAll(
      'SELECT * FROM invite_usages WHERE invite_id = ? ORDER BY accepted_at DESC',
      [inviteId],
    );
    return rows.map(_inviteUsageFromRow).toList();
  }

  @override
  Stream<List<InviteUsage>> watchUsages(String inviteId) {
    if (kIsWeb) {
      return _pollStream(() => listUsages(inviteId));
    }
    return _db
        .watch(
          'SELECT * FROM invite_usages WHERE invite_id = ? ORDER BY accepted_at DESC',
          parameters: [inviteId],
        )
        .map((rows) => rows.map(_inviteUsageFromRow).toList());
  }
}
