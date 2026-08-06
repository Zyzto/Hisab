import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/transaction_scanner/domain/draft_transaction.dart';
import 'package:hisab/features/transaction_scanner/repository/scanner_row_mappers.dart';

void main() {
  group('scannerParseBool', () {
    test('handles bool, int, and string forms', () {
      expect(scannerParseBool(true), isTrue);
      expect(scannerParseBool(1), isTrue);
      expect(scannerParseBool('1'), isTrue);
      expect(scannerParseBool(false), isFalse);
      expect(scannerParseBool(0), isFalse);
      expect(scannerParseBool(null), isFalse);
    });
  });

  group('draftTransactionFromRow', () {
    test('maps columns into DraftTransaction', () {
      final draft = draftTransactionFromRow({
        'id': 'd1',
        'personal_group_id': 'g1',
        'amount_cents': 2500,
        'currency_code': 'SAR',
        'card_last_four': '1234',
        'merchant_name': 'Cafe',
        'merchant_category': null,
        'transaction_date': '2026-01-02T10:00:00.000Z',
        'captured_at': '2026-01-02T10:01:00.000Z',
        'latitude': 24.7,
        'longitude': 46.7,
        'raw_notification_text': 'Paid 25.00',
        'sender_package': 'com.bank',
        'sender_title': 'Bank',
        'status': 'pending',
        'matched_pattern_id': null,
        'confidence': 0.8,
        'created_expense_id': null,
        'created_at': '2026-01-02T10:01:00.000Z',
        'updated_at': '2026-01-02T10:01:00.000Z',
      });

      expect(draft.id, 'd1');
      expect(draft.amountCents, 2500);
      expect(draft.currencyCode, 'SAR');
      expect(draft.merchantName, 'Cafe');
      expect(draft.status, DraftStatus.pending);
      expect(draft.confidence, 0.8);
      expect(draft.hasLocation, isTrue);
    });
  });

  group('senderRuleFromRow / scannerPatternFromRow', () {
    test('maps enabled flags from integers', () {
      final rule = senderRuleFromRow({
        'id': 'r1',
        'package_name': 'com.bank',
        'sender_label': 'Bank',
        'sender_number': null,
        'enabled': 1,
        'match_count': 3,
        'created_at': '2026-01-01T00:00:00.000Z',
      });
      expect(rule.enabled, isTrue);
      expect(rule.matchCount, 3);

      final pattern = scannerPatternFromRow({
        'id': 'p1',
        'name': 'Bank',
        'sender_match': 'com.bank',
        'amount_regex': r'(\d+\.\d{2})',
        'currency_regex': null,
        'card_regex': null,
        'merchant_regex': null,
        'date_regex': null,
        'date_format': null,
        'is_built_in': 0,
        'enabled': 1,
        'success_count': 2,
        'created_at': '2026-01-01T00:00:00.000Z',
      });
      expect(pattern.isBuiltIn, isFalse);
      expect(pattern.enabled, isTrue);
      expect(pattern.successCount, 2);
    });
  });
}
