import '../domain/draft_transaction.dart';
import '../domain/field_span.dart';
import '../domain/scanner_category_rule.dart';
import '../domain/scanner_notification_log.dart';
import '../domain/scanner_pattern.dart';
import '../domain/sender_rule.dart';

DateTime scannerParseDateTime(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString()) ?? DateTime.now();
}

bool scannerParseBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is int) return v == 1;
  return v.toString() == '1';
}

DraftTransaction draftTransactionFromRow(Map<String, dynamic> row) {
  return DraftTransaction(
    id: row['id'] as String,
    targetGroupId: row['personal_group_id'] as String?,
    amountCents: (row['amount_cents'] as num).toInt(),
    currencyCode: row['currency_code'] as String,
    cardLastFour: row['card_last_four'] as String?,
    merchantName: row['merchant_name'] as String?,
    merchantCategory: row['merchant_category'] as String?,
    placeName: row['place_name'] as String?,
    fieldSpans: FieldSpan.decode(row['field_spans_json'] as String?),
    transactionDate: scannerParseDateTime(row['transaction_date']),
    capturedAt: scannerParseDateTime(row['captured_at']),
    latitude: (row['latitude'] as num?)?.toDouble(),
    longitude: (row['longitude'] as num?)?.toDouble(),
    rawNotificationText: row['raw_notification_text'] as String,
    senderPackage: row['sender_package'] as String,
    senderTitle: row['sender_title'] as String?,
    status: DraftStatus.fromString(row['status'] as String? ?? 'pending'),
    matchedPatternId: row['matched_pattern_id'] as String?,
    confidence: (row['confidence'] as num?)?.toDouble() ?? 0.0,
    createdExpenseId: row['created_expense_id'] as String?,
    createdAt: scannerParseDateTime(row['created_at']),
    updatedAt: scannerParseDateTime(row['updated_at']),
  );
}

SenderRule senderRuleFromRow(Map<String, dynamic> row) {
  return SenderRule(
    id: row['id'] as String,
    packageName: row['package_name'] as String,
    senderLabel: row['sender_label'] as String?,
    senderNumber: row['sender_number'] as String?,
    targetGroupId: row['target_group_id'] as String?,
    enabled: scannerParseBool(row['enabled']),
    matchCount: (row['match_count'] as num?)?.toInt() ?? 0,
    createdAt: scannerParseDateTime(row['created_at']),
  );
}

ScannerPattern scannerPatternFromRow(Map<String, dynamic> row) {
  return ScannerPattern(
    id: row['id'] as String,
    name: row['name'] as String,
    senderMatch: row['sender_match'] as String,
    amountRegex: row['amount_regex'] as String,
    currencyRegex: row['currency_regex'] as String?,
    cardRegex: row['card_regex'] as String?,
    merchantRegex: row['merchant_regex'] as String?,
    dateRegex: row['date_regex'] as String?,
    dateFormat: row['date_format'] as String?,
    isBuiltIn: scannerParseBool(row['is_built_in']),
    enabled: scannerParseBool(row['enabled']),
    successCount: (row['success_count'] as num?)?.toInt() ?? 0,
    createdAt: scannerParseDateTime(row['created_at']),
  );
}

ScannerCategoryRule categoryRuleFromRow(Map<String, dynamic> row) {
  return ScannerCategoryRule(
    id: row['id'] as String,
    merchantPattern: row['merchant_pattern'] as String,
    categoryId: row['category_id'] as String,
    source: CategoryRuleSource.fromString(row['source'] as String? ?? 'user'),
    hitCount: (row['hit_count'] as num?)?.toInt() ?? 0,
    createdAt: scannerParseDateTime(row['created_at']),
  );
}

ScannerNotificationLog notificationLogFromRow(Map<String, dynamic> row) {
  return ScannerNotificationLog(
    id: row['id'] as String,
    senderPackage: row['sender_package'] as String,
    senderTitle: row['sender_title'] as String?,
    rawText: row['raw_text'] as String? ?? '',
    postedAt: scannerParseDateTime(row['posted_at']),
    capturedAt: scannerParseDateTime(row['captured_at']),
    outcome: ScannerLogOutcome.fromString(
      row['outcome'] as String? ?? 'pending',
    ),
    reason: row['reason'] as String?,
    amountCents: (row['amount_cents'] as num?)?.toInt(),
    currencyCode: row['currency_code'] as String?,
    merchantName: row['merchant_name'] as String?,
    placeName: row['place_name'] as String?,
    draftId: row['draft_id'] as String?,
    createdExpenseId: row['created_expense_id'] as String?,
    targetGroupId: row['target_group_id'] as String?,
    createdAt: scannerParseDateTime(row['created_at']),
    updatedAt: scannerParseDateTime(row['updated_at']),
  );
}
