/// Itemized breakdown for a consolidated settlement (expense + amount).
class SettlementItem {
  final String expenseId;
  final String title;
  final int amountCents;

  const SettlementItem({
    required this.expenseId,
    required this.title,
    required this.amountCents,
  });

  Map<String, dynamic> toJson() => {
    'expenseId': expenseId,
    'title': title,
    'amountCents': amountCents,
  };

  static SettlementItem fromJson(Map<String, dynamic> j) => SettlementItem(
    expenseId: j['expenseId'] as String? ?? '',
    title: j['title'] as String? ?? '',
    amountCents: (j['amountCents'] as num?)?.toInt() ?? 0,
  );
}
