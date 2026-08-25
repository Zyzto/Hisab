import 'field_span.dart';

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

  /// Destination group (personal or shared). Stored as `personal_group_id`.
  final String? targetGroupId;
  final int amountCents;
  final String currencyCode;
  final String? cardLastFour;
  final String? merchantName;
  final String? merchantCategory;
  final String? placeName;
  final List<FieldSpan> fieldSpans;
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
    this.targetGroupId,
    required this.amountCents,
    required this.currencyCode,
    this.cardLastFour,
    this.merchantName,
    this.merchantCategory,
    this.placeName,
    this.fieldSpans = const [],
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

  /// Legacy alias used by older call sites / docs.
  String? get personalGroupId => targetGroupId;

  DraftTransaction copyWith({
    String? id,
    String? targetGroupId,
    int? amountCents,
    String? currencyCode,
    String? cardLastFour,
    String? merchantName,
    String? merchantCategory,
    String? placeName,
    List<FieldSpan>? fieldSpans,
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
      targetGroupId: targetGroupId ?? this.targetGroupId,
      amountCents: amountCents ?? this.amountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      cardLastFour: cardLastFour ?? this.cardLastFour,
      merchantName: merchantName ?? this.merchantName,
      merchantCategory: merchantCategory ?? this.merchantCategory,
      placeName: placeName ?? this.placeName,
      fieldSpans: fieldSpans ?? this.fieldSpans,
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
  String get displayTitle => merchantName?.isNotEmpty == true
      ? merchantName!
      : senderTitle ?? senderPackage;

  bool get hasLocation => latitude != null && longitude != null;
}
