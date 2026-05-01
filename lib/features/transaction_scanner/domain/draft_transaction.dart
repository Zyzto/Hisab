/// Status of a draft transaction awaiting user review.
enum DraftStatus {
  pending,
  confirmed,
  dismissed,
  duplicate;

  static DraftStatus fromString(String s) =>
      DraftStatus.values.firstWhere((v) => v.name == s, orElse: () => pending);
}

/// A transaction extracted from a captured notification, pending user review.
class DraftTransaction {
  final String id;
  final String? personalGroupId;
  final int amountCents;
  final String currencyCode;
  final String? cardLastFour;
  final String? merchantName;
  final String? merchantCategory;
  final DateTime transactionDate;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final String rawNotificationText;
  final String senderPackage;
  final String? senderTitle;
  final DraftStatus status;
  final String? matchedPatternId;
  final double confidence;
  final String? createdExpenseId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DraftTransaction({
    required this.id,
    this.personalGroupId,
    required this.amountCents,
    required this.currencyCode,
    this.cardLastFour,
    this.merchantName,
    this.merchantCategory,
    required this.transactionDate,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    required this.rawNotificationText,
    required this.senderPackage,
    this.senderTitle,
    this.status = DraftStatus.pending,
    this.matchedPatternId,
    this.confidence = 0.0,
    this.createdExpenseId,
    required this.createdAt,
    required this.updatedAt,
  });

  DraftTransaction copyWith({
    String? id,
    String? personalGroupId,
    int? amountCents,
    String? currencyCode,
    String? cardLastFour,
    String? merchantName,
    String? merchantCategory,
    DateTime? transactionDate,
    DateTime? capturedAt,
    double? latitude,
    double? longitude,
    String? rawNotificationText,
    String? senderPackage,
    String? senderTitle,
    DraftStatus? status,
    String? matchedPatternId,
    double? confidence,
    String? createdExpenseId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DraftTransaction(
      id: id ?? this.id,
      personalGroupId: personalGroupId ?? this.personalGroupId,
      amountCents: amountCents ?? this.amountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      cardLastFour: cardLastFour ?? this.cardLastFour,
      merchantName: merchantName ?? this.merchantName,
      merchantCategory: merchantCategory ?? this.merchantCategory,
      transactionDate: transactionDate ?? this.transactionDate,
      capturedAt: capturedAt ?? this.capturedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rawNotificationText: rawNotificationText ?? this.rawNotificationText,
      senderPackage: senderPackage ?? this.senderPackage,
      senderTitle: senderTitle ?? this.senderTitle,
      status: status ?? this.status,
      matchedPatternId: matchedPatternId ?? this.matchedPatternId,
      confidence: confidence ?? this.confidence,
      createdExpenseId: createdExpenseId ?? this.createdExpenseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Human-readable display title for the review card.
  String get displayTitle =>
      merchantName?.isNotEmpty == true ? merchantName! : senderTitle ?? senderPackage;

  bool get hasLocation => latitude != null && longitude != null;
}
