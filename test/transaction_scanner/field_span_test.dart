import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/transaction_scanner/domain/field_span.dart';
import 'package:hisab/features/transaction_scanner/domain/scanner_notification_log.dart';
import 'package:hisab/features/transaction_scanner/widgets/notification_annotator.dart';

void main() {
  test('encodes and decodes spans', () {
    const spans = [
      FieldSpan(role: FieldRole.amount, start: 2, end: 7),
      FieldSpan(role: FieldRole.merchant, start: 10, end: 19),
    ];
    final raw = FieldSpan.encode(spans);
    final back = FieldSpan.decode(raw);
    expect(back.length, 2);
    expect(back.first.role, FieldRole.amount);
    expect(back.last.end, 19);
  });

  test('valuesFromSpans parses amounts that include currency text', () {
    const body = 'Paid 42.50 SAR at Store';
    final values = valuesFromSpans(body, const [
      FieldSpan(role: FieldRole.amount, start: 5, end: 14),
    ]);
    expect(values.amountCents, 4250);
  });

  test('log outcome storage round-trip', () {
    for (final o in ScannerLogOutcome.values) {
      expect(ScannerLogOutcome.fromString(o.storageName), o);
    }
    expect(ScannerLogOutcome.ignoredOtp.isIgnored, isTrue);
    expect(ScannerLogOutcome.added.isIgnored, isFalse);
  });
}
