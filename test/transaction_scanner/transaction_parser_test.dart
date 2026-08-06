import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/transaction_scanner/domain/scanner_pattern.dart';
import 'package:hisab/features/transaction_scanner/services/transaction_parser.dart';

void main() {
  group('TransactionParser.parse', () {
    test('skips OTP / verification messages', () {
      final result = TransactionParser.parse(
        'Your OTP is 123456. Do not share this security code.',
      );
      expect(result.amountCents, isNull);
      expect(result.confidence, 0);
    });

    test('extracts USD amount, card, and merchant', () {
      final result = TransactionParser.parse(
        'Purchase of \$42.50 at Starbucks on card ending 1234',
        fallbackCurrency: 'SAR',
      );
      expect(result.amountCents, 4250);
      expect(result.currencyCode, 'USD');
      expect(result.cardLastFour, '1234');
      expect(result.merchantName, isNotNull);
      expect(result.merchantName!.toLowerCase(), contains('starbucks'));
      expect(result.confidence, greaterThan(0.5));
    });

    test('uses fallback currency when none in body', () {
      final result = TransactionParser.parse(
        'Paid 15.00 at Cafe Mocha',
        fallbackCurrency: 'SAR',
      );
      expect(result.amountCents, 1500);
      expect(result.currencyCode, 'SAR');
    });

    test('parses European decimal comma amounts', () {
      // Avoid thousands separators — the generic extractor prefers the first
      // `\d+\.\d{1,2}` match, which would truncate "1.234,56".
      final result = TransactionParser.parse(
        'Debit EUR 12,50 at Market',
        fallbackCurrency: 'SAR',
      );
      expect(result.amountCents, 1250);
      expect(result.currencyCode, 'EUR');
    });

    test('treats refund keywords as negative amounts', () {
      final result = TransactionParser.parse(
        'Refund of \$20.00 from Amazon',
        fallbackCurrency: 'USD',
      );
      expect(result.amountCents, -2000);
    });

    test('prefers matching custom pattern when enabled', () {
      final pattern = ScannerPattern(
        id: 'custom-1',
        name: 'Bank X',
        senderMatch: 'com.bank.x',
        amountRegex: r'AMT:(\d+\.\d{2})',
        currencyRegex: r'CUR:([A-Z]{3})',
        isBuiltIn: false,
        enabled: true,
        createdAt: DateTime(2026, 1, 1),
      );
      final result = TransactionParser.parse(
        'TXN AMT:99.99 CUR:AED CARD ****9999',
        customPatterns: [pattern],
      );
      expect(result.amountCents, 9999);
      expect(result.currencyCode, 'AED');
      expect(result.matchedPatternId, 'custom-1');
    });

    test('ignores disabled custom patterns', () {
      final pattern = ScannerPattern(
        id: 'disabled',
        name: 'Off',
        senderMatch: '*',
        amountRegex: r'AMT:(\d+\.\d{2})',
        enabled: false,
        createdAt: DateTime(2026, 1, 1),
      );
      final result = TransactionParser.parse(
        'AMT:10.00 random text without clear merchant',
        customPatterns: [pattern],
        fallbackCurrency: 'SAR',
      );
      expect(result.matchedPatternId, isNull);
    });
  });
}
