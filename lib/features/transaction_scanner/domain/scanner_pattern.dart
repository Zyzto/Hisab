/// A regex-based extraction pattern for parsing transaction notifications.
class ScannerPattern {
  final String id;
  final String name;
  final String senderMatch;
  final String amountRegex;
  final String? currencyRegex;
  final String? cardRegex;
  final String? merchantRegex;
  final String? dateRegex;
  final String? dateFormat;
  final bool isBuiltIn;
  final bool enabled;
  final int successCount;
  final DateTime createdAt;

  const ScannerPattern({
    required this.id,
    required this.name,
    required this.senderMatch,
    required this.amountRegex,
    this.currencyRegex,
    this.cardRegex,
    this.merchantRegex,
    this.dateRegex,
    this.dateFormat,
    this.isBuiltIn = false,
    this.enabled = true,
    this.successCount = 0,
    required this.createdAt,
  });

  ScannerPattern copyWith({
    String? id,
    String? name,
    String? senderMatch,
    String? amountRegex,
    String? currencyRegex,
    String? cardRegex,
    String? merchantRegex,
    String? dateRegex,
    String? dateFormat,
    bool? isBuiltIn,
    bool? enabled,
    int? successCount,
    DateTime? createdAt,
  }) {
    return ScannerPattern(
      id: id ?? this.id,
      name: name ?? this.name,
      senderMatch: senderMatch ?? this.senderMatch,
      amountRegex: amountRegex ?? this.amountRegex,
      currencyRegex: currencyRegex ?? this.currencyRegex,
      cardRegex: cardRegex ?? this.cardRegex,
      merchantRegex: merchantRegex ?? this.merchantRegex,
      dateRegex: dateRegex ?? this.dateRegex,
      dateFormat: dateFormat ?? this.dateFormat,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      enabled: enabled ?? this.enabled,
      successCount: successCount ?? this.successCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
