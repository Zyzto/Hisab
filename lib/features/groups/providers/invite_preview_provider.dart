import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/settle_up_service.dart';
import '../../../domain/domain.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

typedef InvitePreviewRpc = Future<dynamic> Function(
  String rpcName,
  Map<String, dynamic> params,
);

final invitePreviewRpcProvider = Provider<InvitePreviewRpc>((ref) {
  final client = ref.read(supabaseClientProvider);
  return (rpcName, params) async {
    return await client.rpc(rpcName, params: params);
  };
});

class InvitePreviewData {
  const InvitePreviewData({
    required this.invite,
    required this.group,
    required this.participants,
    required this.expenses,
    required this.participantRoles,
  });

  final GroupInvite invite;
  final Group group;
  final List<Participant> participants;
  final List<Expense> expenses;
  final Map<String, String?> participantRoles;

  List<ParticipantBalance> get balances =>
      computeBalances(participants, expenses, group.currencyCode);

  List<SettlementTransaction> get settlements => computeSettlements(
    group.settlementMethod,
    balances,
    participants,
    expenses,
    group.currencyCode,
    group.treasurerParticipantId,
  );
}

DateTime _parseDateTime(Object? value) => DateTime.parse(value.toString());

DateTime? _parseDateTimeNullable(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

Map<String, int> _parseSplitShares(Object? value) {
  if (value == null) return {};
  dynamic parsed = value;
  if (value is String) {
    if (value.trim().isEmpty) return {};
    parsed = jsonDecode(value);
  }
  if (parsed is! Map) return {};
  final out = <String, int>{};
  for (final entry in parsed.entries) {
    out[entry.key.toString()] = (entry.value as num?)?.toInt() ?? 0;
  }
  return out;
}

SettlementMethod _parseSettlementMethod(String? value) {
  switch (value) {
    case 'pairwise':
      return SettlementMethod.pairwise;
    case 'consolidated':
      return SettlementMethod.consolidated;
    case 'treasurer':
      return SettlementMethod.treasurer;
    case 'greedy':
    default:
      return SettlementMethod.greedy;
  }
}

SplitType _parseSplitType(String? value) {
  switch (value) {
    case 'parts':
      return SplitType.parts;
    case 'amounts':
      return SplitType.amounts;
    case 'equal':
    default:
      return SplitType.equal;
  }
}

TransactionType _parseTransactionType(String? value) {
  switch (value) {
    case 'income':
      return TransactionType.income;
    case 'transfer':
      return TransactionType.transfer;
    case 'expense':
    default:
      return TransactionType.expense;
  }
}

List<String>? _parseReceiptImagePaths(Object? value) {
  if (value == null) return null;
  if (value is List) {
    final items = value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    return items.isEmpty ? null : items;
  }
  if (value is String) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        final items = decoded
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
        return items.isEmpty ? null : items;
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

final invitePreviewDataProvider = FutureProvider.family<InvitePreviewData?, String>((
  ref,
  token,
) async {
  final rpc = ref.read(invitePreviewRpcProvider);

  final groupResult = await rpc('get_invite_preview_group', {'p_token': token});
  if (groupResult == null || (groupResult is List && groupResult.isEmpty)) {
    return null;
  }
  final groupRow = (groupResult is List ? groupResult.first : groupResult)
      as Map<String, dynamic>;

  final participantsResult = await rpc('get_invite_preview_participants', {
    'p_token': token,
  });
  final participantsRows = (participantsResult is List)
      ? participantsResult.cast<Map<String, dynamic>>()
      : <Map<String, dynamic>>[];

  final expensesResult = await rpc('get_invite_preview_expenses', {
    'p_token': token,
    'p_limit': 200,
  });
  final expensesRows = (expensesResult is List)
      ? expensesResult.cast<Map<String, dynamic>>()
      : <Map<String, dynamic>>[];

  final group = Group(
    id: groupRow['group_id'] as String,
    name: groupRow['group_name'] as String? ?? '',
    currencyCode: groupRow['group_currency_code'] as String? ?? 'USD',
    createdAt: _parseDateTime(groupRow['group_created_at']),
    updatedAt: _parseDateTime(groupRow['group_updated_at']),
    settlementMethod: _parseSettlementMethod(
      groupRow['group_settlement_method'] as String?,
    ),
    treasurerParticipantId: groupRow['group_treasurer_participant_id'] as String?,
    allowMemberSettleForOthers:
        groupRow['group_allow_member_settle_for_others'] == true,
  );

  final invite = GroupInvite(
    id: groupRow['invite_id'] as String,
    groupId: groupRow['group_id'] as String,
    token: token,
    role: 'member',
    createdAt: DateTime.now(),
    accessMode: InviteAccessMode.fromValue(
      groupRow['invite_access_mode'] as String?,
    ),
  );

  final participants = participantsRows
      .map(
        (row) => Participant(
          id: row['id'] as String,
          groupId: row['group_id'] as String,
          name: row['name'] as String? ?? '',
          order: (row['sort_order'] as num?)?.toInt() ?? 0,
          userId: null,
          avatarId: null,
          leftAt: _parseDateTimeNullable(row['left_at']),
          createdAt: _parseDateTime(row['created_at']),
          updatedAt: _parseDateTime(row['updated_at']),
        ),
      )
      .toList();

  final participantRoles = <String, String?>{
    for (final row in participantsRows)
      row['id'] as String: row['member_role'] as String?,
  };

  final expenses = expensesRows
      .map(
        (row) => Expense(
          id: row['id'] as String,
          groupId: row['group_id'] as String,
          payerParticipantId: row['payer_participant_id'] as String,
          amountCents: (row['amount_cents'] as num?)?.toInt() ?? 0,
          currencyCode: row['currency_code'] as String? ?? group.currencyCode,
          exchangeRate: (row['exchange_rate'] as num?)?.toDouble() ?? 1.0,
          baseAmountCents: (row['base_amount_cents'] as num?)?.toInt(),
          title: row['title'] as String? ?? '',
          description: null,
          date: _parseDateTime(row['date']),
          splitType: _parseSplitType(row['split_type'] as String?),
          splitShares: _parseSplitShares(row['split_shares_json']),
          createdAt: _parseDateTime(row['created_at']),
          updatedAt: _parseDateTime(row['updated_at']),
          transactionType: _parseTransactionType(row['type'] as String?),
          toParticipantId: row['to_participant_id'] as String?,
          tag: null,
          lineItems: null,
          receiptImagePath: row['receipt_image_path'] as String?,
          receiptImagePaths: _parseReceiptImagePaths(row['receipt_image_paths']),
        ),
      )
      .toList();

  return InvitePreviewData(
    invite: invite,
    group: group,
    participants: participants,
    expenses: expenses,
    participantRoles: participantRoles,
  );
});
