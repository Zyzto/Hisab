import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/transaction_scanner/domain/field_span.dart';
import 'package:hisab/features/transaction_scanner/services/pattern_from_spans.dart';
import 'package:hisab/features/transaction_scanner/services/transaction_parser.dart';

void main() {
  test('builds a pattern that re-parses the sample amount', () {
    const body = 'Purchase of 42.50 SAR at Starbucks in Riyadh';
    final parsed = TransactionParser.parse(body, fallbackCurrency: 'USD');
    expect(parsed.amountCents, 4250);

    final taught = patternFromSpans(
      id: 'taught-1',
      name: 'Taught',
      senderMatch: 'com.bank',
      body: body,
      spans: parsed.fieldSpans,
      createdAt: DateTime(2026, 1, 1),
    );
    expect(taught, isNotNull);

    final again = TransactionParser.parse(
      body,
      customPatterns: [taught!],
      fallbackCurrency: 'USD',
    );
    expect(again.amountCents, 4250);
    expect(again.matchedPatternId, 'taught-1');
  });

  test('taught pattern matches a different amount than the sample', () {
    const sample = 'Purchase of 42.50 SAR at Starbucks in Riyadh';
    final parsed = TransactionParser.parse(sample, fallbackCurrency: 'USD');
    final taught = patternFromSpans(
      id: 'taught-1',
      name: 'Taught',
      senderMatch: 'com.bank',
      body: sample,
      spans: parsed.fieldSpans,
      createdAt: DateTime(2026, 1, 1),
    );
    expect(taught, isNotNull);

    final again = TransactionParser.parse(
      'Purchase of 99.00 SAR at Starbucks in Riyadh',
      customPatterns: [taught!],
      fallbackCurrency: 'USD',
    );
    expect(again.amountCents, 9900);
    expect(again.matchedPatternId, 'taught-1');
  });

  test('returns null without an amount span', () {
    expect(
      patternFromSpans(
        id: 'x',
        name: 'x',
        senderMatch: '*',
        body: 'hello',
        spans: const [FieldSpan(role: FieldRole.merchant, start: 0, end: 5)],
        createdAt: DateTime(2026, 1, 1),
      ),
      isNull,
    );
  });

  test('OTP skip reason is set', () {
    final result = TransactionParser.parse('Your OTP is 123456');
    expect(result.skipReason, ParseSkipReason.otp);
    expect(result.amountCents, isNull);
  });

  test('no-amount skip reason', () {
    final result = TransactionParser.parse('Your account is active today');
    expect(result.skipReason, ParseSkipReason.noAmount);
  });
}
