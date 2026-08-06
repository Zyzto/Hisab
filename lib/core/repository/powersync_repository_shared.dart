part of 'powersync_repository.dart';

const _uuid = Uuid();
const _archiveAutoFreezeMarker = archiveAutoFreezeSnapshotMarker;

/// On web, PowerSync/sqlite3_web can emit raw JS objects (LegacyJavaScriptObject)
/// in update streams instead of Dart UpdateNotification, causing type errors.
/// Use polling instead of watch() to avoid the broken stream.
///
/// Period is intentionally >1s: iOS Safari + Flutter web janks when many
/// StreamProviders rebuild every tick. Fingerprints skip unchanged yields.
const _webPollPeriod = Duration(milliseconds: 1500);

Stream<T> _pollStream<T>(
  Future<T> Function() fetch, {
  Object? Function(T value)? fingerprint,
}) async* {
  var prev = await fetch();
  yield prev;
  var prevFp = fingerprint?.call(prev);
  await for (final _ in Stream.periodic(_webPollPeriod)) {
    final next = await fetch();
    if (fingerprint != null) {
      final fp = fingerprint(next);
      if (fp == prevFp) continue;
      prevFp = fp;
    } else if (next == prev) {
      continue;
    }
    prev = next;
    yield next;
  }
}

Object? _groupFp(Group? g) {
  if (g == null) return null;
  return Object.hash(
    g.id,
    g.name,
    g.currencyCode,
    g.updatedAt.millisecondsSinceEpoch,
    g.settlementMethod,
    g.treasurerParticipantId,
    g.settlementFreezeAt?.millisecondsSinceEpoch,
    g.settlementSnapshotJson,
    g.ownerId,
    g.allowMemberAddExpense,
    g.allowMemberChangeSettings,
    g.allowExpenseAsOtherParticipant,
    g.allowMemberSettleForOthers,
    g.icon,
    g.color,
    g.archivedAt?.millisecondsSinceEpoch,
    g.isPersonal,
    g.budgetAmountCents,
  );
}

Object? _expenseFp(Expense? e) {
  if (e == null) return null;
  return Object.hash(
    e.id,
    e.groupId,
    e.amountCents,
    e.currencyCode,
    e.title,
    e.date.millisecondsSinceEpoch,
    e.updatedAt.millisecondsSinceEpoch,
    e.payerParticipantId,
    e.splitType,
    e.tag,
    e.imagePath,
    e.exchangeRate,
  );
}

Object? _memberFp(GroupMember? m) {
  if (m == null) return null;
  return Object.hash(m.id, m.groupId, m.userId, m.role, m.participantId);
}

Object _groupsListFp(List<Group> list) => Object.hashAll(list.map(_groupFp));

Object _expensesListFp(List<Expense> list) =>
    Object.hashAll(list.map(_expenseFp));

Object _membersListFp(List<GroupMember> list) =>
    Object.hashAll(list.map(_memberFp));

Object? _participantFp(Participant p) => Object.hash(
  p.id,
  p.groupId,
  p.name,
  p.order,
  p.userId,
  p.avatarId,
  p.leftAt?.millisecondsSinceEpoch,
  p.updatedAt.millisecondsSinceEpoch,
);

Object _participantsListFp(List<Participant> list) =>
    Object.hashAll(list.map(_participantFp));

Object _stringSetFp(Set<String> set) {
  final sorted = set.toList()..sort();
  return Object.hashAll(sorted);
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

bool _isFilledValue(dynamic v) {
  if (v == null) return false;
  final text = v.toString().trim();
  return text.isNotEmpty;
}

bool _shouldAutoUnfreezeOnUnarchive(dynamic settlementSnapshotJson) {
  return settlementSnapshotJson?.toString() == _archiveAutoFreezeMarker;
}

@visibleForTesting
bool shouldAutoFreezeOnArchive(dynamic settlementFreezeAt) {
  return !_isFilledValue(settlementFreezeAt);
}

@visibleForTesting
bool shouldAutoUnfreezeOnUnarchive(dynamic settlementSnapshotJson) {
  return _shouldAutoUnfreezeOnUnarchive(settlementSnapshotJson);
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
  if (v is Map) {
    try {
      return v.map((k, val) => MapEntry(k.toString(), (val as num).toInt()));
    } catch (e, st) {
      Log.warning('Failed to parse split shares map', error: e, stackTrace: st);
    }
    return {};
  }
  try {
    final decoded = jsonDecode(v.toString());
    if (decoded is Map) {
      return decoded.map(
        (k, val) => MapEntry(k.toString(), (val as num).toInt()),
      );
    }
  } catch (e, st) {
    Log.warning('Failed to decode split shares JSON', error: e, stackTrace: st);
  }
  return {};
}

List<ReceiptLineItem>? _parseLineItems(dynamic v) {
  if (v == null || v.toString().isEmpty) return null;
  if (v is List) {
    try {
      return v
          .map((e) => ReceiptLineItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      Log.warning('Failed to parse line items list', error: e, stackTrace: st);
    }
    return null;
  }
  try {
    final decoded = jsonDecode(v.toString());
    if (decoded is List) {
      return decoded
          .map((e) => ReceiptLineItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  } catch (e, st) {
    Log.warning('Failed to decode line items JSON', error: e, stackTrace: st);
  }
  return null;
}

List<String>? _parseImagePaths(dynamic v) {
  if (v == null || v.toString().trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(v.toString());
    if (decoded is List) {
      final list = decoded
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      return list.isEmpty ? null : list;
    }
  } catch (e, st) {
    Log.warning('Failed to decode image_paths JSON', error: e, stackTrace: st);
  }
  return null;
}

String? _effectiveImagePathFromRow(Map<String, dynamic> row) {
  final paths = _parseImagePaths(row['image_paths']);
  if (paths != null && paths.isNotEmpty) return paths.first;
  return row['image_path'] as String?;
}

List<String>? _effectiveImagePathsFromRow(Map<String, dynamic> row) {
  final paths = _parseImagePaths(row['image_paths']);
  if (paths != null && paths.isNotEmpty) return paths;
  final single = row['image_path'] as String?;
  if (single != null && single.isNotEmpty) return [single];
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
  allowExpenseAsOtherParticipant:
      row['allow_expense_as_other_participant'] == null
      ? true
      : _parseBool(row['allow_expense_as_other_participant']),
  allowMemberSettleForOthers: row['allow_member_settle_for_others'] == null
      ? false
      : _parseBool(row['allow_member_settle_for_others']),
  icon: row['icon'] as String?,
  color: _colorToUnsigned((row['color'] as num?)?.toInt()),
  archivedAt: _parseDateTimeNullable(row['archived_at']),
  isPersonal: (row['is_personal'] as num?)?.toInt() == 1,
  budgetAmountCents: (row['budget_amount_cents'] as num?)?.toInt(),
);

Participant _participantFromRow(Map<String, dynamic> row) => Participant(
  id: row['id'] as String,
  groupId: row['group_id'] as String,
  name: row['name'] as String? ?? '',
  order: (row['sort_order'] as num?)?.toInt() ?? 0,
  userId: row['user_id'] as String?,
  avatarId: row['avatar_id'] as String?,
  leftAt: _parseDateTimeNullable(row['left_at']),
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
  imagePath: _effectiveImagePathFromRow(row),
  imagePaths: _effectiveImagePathsFromRow(row),
);

ExpenseTag _tagFromRow(Map<String, dynamic> row) => ExpenseTag(
  id: row['id'] as String,
  groupId: row['group_id'] as String,
  label: row['label'] as String? ?? '',
  iconName: row['icon_name'] as String? ?? 'label',
  colorHex: row['color'] as String?,
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
  accessMode: InviteAccessMode.fromValue(row['access_mode'] as String?),
);

InviteUsage _inviteUsageFromRow(Map<String, dynamic> row) => InviteUsage(
  id: row['id'] as String,
  inviteId: row['invite_id'] as String,
  userId: row['user_id'] as String,
  acceptedAt: _parseDateTime(row['accepted_at']),
);

String _nowIso() => DateTime.now().toUtc().toIso8601String();

/// Returns normalized `#RRGGBB` or null when missing/invalid.
String? _normalizeTagColorHex(String? colorHex) {
  if (colorHex == null) return null;
  var s = colorHex.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length != 6) return null;
  if (int.tryParse(s, radix: 16) == null) return null;
  return '#${s.toUpperCase()}';
}

/// When true, new [pending_writes] rows are marked silent (import/restore).
bool _enqueueSilentDefault = false;

/// Runs [fn] so any queued writes are marked `silent=1` for notify-suppress push.
Future<T> runWithSilentPendingWrites<T>(Future<T> Function() fn) async {
  final prev = _enqueueSilentDefault;
  _enqueueSilentDefault = true;
  try {
    return await fn();
  } finally {
    _enqueueSilentDefault = prev;
  }
}

/// Enqueue an offline write for later push.
///
/// When [silent] is true (or [runWithSilentPendingWrites] is active), SyncEngine
/// pushes under notify-suppress.
Future<void> _enqueue(
  PowerSyncDatabase db, {
  required String tableName,
  required String operation,
  required String rowId,
  Map<String, dynamic>? data,
  bool? silent,
}) async {
  final isSilent = silent ?? _enqueueSilentDefault;
  final id = _uuid.v4();
  await db.execute(
    'INSERT INTO pending_writes (id, table_name, operation, row_id, data_json, created_at, silent) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [
      id,
      tableName,
      operation,
      rowId,
      data != null ? jsonEncode(data) : null,
      _nowIso(),
      isSilent ? 1 : 0,
    ],
  );
  Log.debug(
    'Queued pending write: $operation on $tableName/$rowId silent=$isSilent',
  );
}

bool _shouldQueueOffline({required bool isLocalOnly, required bool isOnline}) =>
    !isLocalOnly && !isOnline;
