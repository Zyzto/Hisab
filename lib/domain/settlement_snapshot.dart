import 'dart:convert';

import 'participant_balance.dart';
import 'settlement_transaction.dart';

/// Immutable snapshot of balances and settlements at freeze time.
class SettlementSnapshot {
  final DateTime frozenAt;
  final List<ParticipantBalance> balances;
  final List<SettlementTransaction> settlements;

  const SettlementSnapshot({
    required this.frozenAt,
    required this.balances,
    required this.settlements,
  });

  String toJsonString() => jsonEncode({
    'frozenAt': frozenAt.millisecondsSinceEpoch,
    'balances': balances
        .map(
          (b) => {
            'participantId': b.participantId,
            'balanceCents': b.balanceCents,
            'currencyCode': b.currencyCode,
          },
        )
        .toList(),
    'settlements': settlements.map((s) => s.toJson()).toList(),
  });

  static SettlementSnapshot fromJsonString(String jsonStr) {
    final j = jsonDecode(jsonStr) as Map<String, dynamic>;
    final balancesList = j['balances'] as List<dynamic>? ?? [];
    final settlementsList = j['settlements'] as List<dynamic>? ?? [];
    return SettlementSnapshot(
      frozenAt: DateTime.fromMillisecondsSinceEpoch(
        (j['frozenAt'] as num?)?.toInt() ?? 0,
      ),
      balances: balancesList
          .map(
            (e) => ParticipantBalance(
              participantId: e['participantId'] as String? ?? '',
              balanceCents: (e['balanceCents'] as num?)?.toInt() ?? 0,
              currencyCode: e['currencyCode'] as String? ?? 'USD',
            ),
          )
          .toList(),
      settlements: settlementsList
          .map((e) => SettlementTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
