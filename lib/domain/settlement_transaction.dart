import 'settlement_item.dart';

/// Result of the settle-up algorithm: one transfer from debtor to creditor.
/// [amountCents] is in smallest currency unit.
/// [items] is optional itemized breakdown for consolidated method.
class SettlementTransaction {
  final String fromParticipantId;
  final String toParticipantId;
  final int amountCents;
  final String currencyCode;
  final List<SettlementItem>? items;

  const SettlementTransaction({
    required this.fromParticipantId,
    required this.toParticipantId,
    required this.amountCents,
    required this.currencyCode,
    this.items,
  });

  Map<String, dynamic> toJson() => {
    'fromParticipantId': fromParticipantId,
    'toParticipantId': toParticipantId,
    'amountCents': amountCents,
    'currencyCode': currencyCode,
    if (items != null && items!.isNotEmpty)
      'items': items!.map((e) => e.toJson()).toList(),
  };

  static SettlementTransaction fromJson(Map<String, dynamic> j) {
    List<SettlementItem>? items;
    final itemsList = j['items'] as List<dynamic>?;
    if (itemsList != null && itemsList.isNotEmpty) {
      items = itemsList
          .map((e) => SettlementItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return SettlementTransaction(
      fromParticipantId: j['fromParticipantId'] as String? ?? '',
      toParticipantId: j['toParticipantId'] as String? ?? '',
      amountCents: (j['amountCents'] as num?)?.toInt() ?? 0,
      currencyCode: j['currencyCode'] as String? ?? 'USD',
      items: items,
    );
  }
}
