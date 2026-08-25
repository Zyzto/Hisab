/// Outcome of a captured notification from a watched app.
enum ScannerLogOutcome {
  pending,
  added,
  dismissed,
  ignoredOtp,
  ignoredNoAmount,
  ignoredDuplicate,
  ignoredFilter;

  static ScannerLogOutcome fromString(String s) {
    switch (s) {
      case 'pending':
        return ScannerLogOutcome.pending;
      case 'added':
        return ScannerLogOutcome.added;
      case 'dismissed':
        return ScannerLogOutcome.dismissed;
      case 'ignored_otp':
        return ScannerLogOutcome.ignoredOtp;
      case 'ignored_no_amount':
        return ScannerLogOutcome.ignoredNoAmount;
      case 'ignored_duplicate':
        return ScannerLogOutcome.ignoredDuplicate;
      case 'ignored_filter':
        return ScannerLogOutcome.ignoredFilter;
      default:
        return ScannerLogOutcome.pending;
    }
  }

  String get storageName {
    switch (this) {
      case ScannerLogOutcome.pending:
        return 'pending';
      case ScannerLogOutcome.added:
        return 'added';
      case ScannerLogOutcome.dismissed:
        return 'dismissed';
      case ScannerLogOutcome.ignoredOtp:
        return 'ignored_otp';
      case ScannerLogOutcome.ignoredNoAmount:
        return 'ignored_no_amount';
      case ScannerLogOutcome.ignoredDuplicate:
        return 'ignored_duplicate';
      case ScannerLogOutcome.ignoredFilter:
        return 'ignored_filter';
    }
  }

  bool get isIgnored =>
      this == ScannerLogOutcome.dismissed ||
      this == ScannerLogOutcome.ignoredOtp ||
      this == ScannerLogOutcome.ignoredNoAmount ||
      this == ScannerLogOutcome.ignoredDuplicate ||
      this == ScannerLogOutcome.ignoredFilter;

  String get reasonKey {
    switch (this) {
      case ScannerLogOutcome.pending:
        return 'scanner_log_pending';
      case ScannerLogOutcome.added:
        return 'scanner_log_added';
      case ScannerLogOutcome.dismissed:
        return 'scanner_log_dismissed';
      case ScannerLogOutcome.ignoredOtp:
        return 'scanner_log_otp';
      case ScannerLogOutcome.ignoredNoAmount:
        return 'scanner_log_no_amount';
      case ScannerLogOutcome.ignoredDuplicate:
        return 'scanner_log_duplicate';
      case ScannerLogOutcome.ignoredFilter:
        return 'scanner_log_filtered';
    }
  }
}

/// Local history row for a notification the scanner saw.
class ScannerNotificationLog {
  final String id;
  final String senderPackage;
  final String? senderTitle;
  final String rawText;
  final DateTime postedAt;
  final DateTime capturedAt;
  final ScannerLogOutcome outcome;
  final String? reason;
  final int? amountCents;
  final String? currencyCode;
  final String? merchantName;
  final String? placeName;
  final String? draftId;
  final String? createdExpenseId;
  final String? targetGroupId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScannerNotificationLog({
    required this.id,
    required this.senderPackage,
    this.senderTitle,
    required this.rawText,
    required this.postedAt,
    required this.capturedAt,
    required this.outcome,
    this.reason,
    this.amountCents,
    this.currencyCode,
    this.merchantName,
    this.placeName,
    this.draftId,
    this.createdExpenseId,
    this.targetGroupId,
    required this.createdAt,
    required this.updatedAt,
  });

  ScannerNotificationLog copyWith({
    ScannerLogOutcome? outcome,
    String? reason,
    String? draftId,
    String? createdExpenseId,
    String? targetGroupId,
    DateTime? updatedAt,
  }) {
    return ScannerNotificationLog(
      id: id,
      senderPackage: senderPackage,
      senderTitle: senderTitle,
      rawText: rawText,
      postedAt: postedAt,
      capturedAt: capturedAt,
      outcome: outcome ?? this.outcome,
      reason: reason ?? this.reason,
      amountCents: amountCents,
      currencyCode: currencyCode,
      merchantName: merchantName,
      placeName: placeName,
      draftId: draftId ?? this.draftId,
      createdExpenseId: createdExpenseId ?? this.createdExpenseId,
      targetGroupId: targetGroupId ?? this.targetGroupId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
