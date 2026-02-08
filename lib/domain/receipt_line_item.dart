/// A single line item on a bill/receipt (description + amount in cents).
class ReceiptLineItem {
  final String description;
  final int amountCents;

  const ReceiptLineItem({required this.description, required this.amountCents});

  Map<String, dynamic> toJson() => {
    'description': description,
    'amountCents': amountCents,
  };

  static ReceiptLineItem fromJson(Map<String, dynamic> json) {
    return ReceiptLineItem(
      description: json['description'] as String? ?? '',
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
    );
  }
}
