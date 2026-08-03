import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/receipt/receipt_local_extractor.dart';
import 'package:hisab/core/receipt/receipt_scan_types.dart';

void main() {
  final fallback = DateTime(2024, 1, 15);

  group('parseReceiptAmount', () {
    test('parses plain and decimal amounts', () {
      expect(parseReceiptAmount('12.50'), 12.50);
      expect(parseReceiptAmount(r'$42'), 42);
      expect(parseReceiptAmount('1,234.56'), 1234.56);
      expect(parseReceiptAmount('1.234,56'), 1234.56);
    });
  });

  group('repair + noisy OCR', () {
    test('repairs spaced amounts and amount-to-pay typos', () {
      final repaired = repairReceiptOcrText(
        'Amount te Pi 264,00\nSAR 162 .00 Net TTL\nVTA 34.43',
      );
      expect(repaired, contains('Amount to pay'));
      expect(repaired, contains('264.00'));
      expect(repaired, contains('162.00'));
      expect(repaired, contains('VAT'));
    });

    test('extracts LAZA-like totals without taking VAT rate', () {
      const text = '''
LAZA UZBEK CUISINE
LUNCH OFFER-OSH PLOV MEDIU 189.00
Subtotal 164.35
24.65 (15.0%) ضريبة القيمة المضافة
الإجمالي 189.00
Total
''';
      final d = extractReceiptDetails(text, fallback);
      expect(d.store, contains('LAZA'));
      expect(d.total, closeTo(189.0, 0.01));
      expect(d.vat, closeTo(24.65, 0.01));
    });

    test('strips leading OCR 4 on VAT and payment', () {
      const text = '''
Special La casa - Large 45.00
Penne Pomodoro 31.00
Chicken 18.00
Subtotal 81.74
VAT (15.0%) 412.26
Payment -POS 94.00
''';
      final d = extractReceiptDetails(text, fallback);
      expect(d.store.toLowerCase(), contains('casa'));
      expect(d.total, closeTo(94.0, 0.01));
      expect(d.vat, closeTo(12.26, 0.01));
    });

    test('prefers Subtotal over repeating unit-price amounts', () {
      const text = '''
Texas Roadhouse
1 L FRCATCH 2P 49.00
Unit Price 69,00
1 L FRCATCH 2P 49.00
Unit Price 69,00
1 L Buff Chk San 49.00
Subtotal 162.00
Amount Due
VAT 15% 21.13
''';
      final d = extractReceiptDetails(text, fallback);
      expect(d.store.toLowerCase(), contains('texas'));
      expect(d.total, closeTo(162.0, 0.05));
      expect(d.vat, closeTo(21.13, 0.05));
    });

    test('infers FamilyMart total from items and discounts', () {
      const text = '''
FamilyMart
Oden Set : Spicy Korean 2.20
King Crab Chunk 2.20
Korean Odeng Fish Cake 2.20
Seafood Tofu Fish Cake 2.20
Oden Set : Creamy Tom Yun 3.30
2 each @ 2.20 4.40
Kirin Kocha Milk 500ml ea 10.20
Chicken Slice + Egg Mayo Sandwi 6.90
Salted Salwon Onigiri ea 4.90
KSFRckSgrPear500ml ea 4.20
Egg Mayo Sandwich ea 4.90
LovintCrunkyChocoStick54g ea 6.10
Paper Bag - L 0.50
SUBTOTAL
AllDay-Onigiri@3.90 -1.00
RTE Clearance 25% Timebase -1.73
ROUNDING -0.02
TOTAL
SST 2.73
''';
      final d = extractReceiptDetails(text, fallback);
      expect(d.store, contains('FamilyMart'));
      expect(d.total, closeTo(51.45, 0.05));
      expect(d.vat, closeTo(2.73, 0.01));
      expect(d.items.length, greaterThanOrEqualTo(8));
    });
  });

  group('extractReceiptFromOcrText', () {
    test('extracts vendor date total from English receipt', () {
      const text = '''
Coffee House Downtown
Tel: 555-0100
Date: 12/03/2024
Latte          4.50
Muffin         3.00
TOTAL         7.50
Thank you
''';
      final result = extractReceiptFromOcrText(text, fallback);
      expect(result, isA<ReceiptScanParsed>());
      final parsed = result as ReceiptScanParsed;
      expect(parsed.vendor, contains('Coffee'));
      expect(parsed.total, 7.50);
      expect(parsed.date, DateTime(2024, 3, 12));
    });

    test('extracts total with Arabic label', () {
      const text = '''
متجر النور
الإجمالي 25.00
''';
      final result = extractReceiptFromOcrText(text, fallback);
      expect(result, isA<ReceiptScanParsed>());
      expect((result as ReceiptScanParsed).total, 25.00);
    });

    test('falls back when no total', () {
      const text = 'Hello world\nNo amounts here';
      final result = extractReceiptFromOcrText(text, fallback);
      expect(result, isA<ReceiptScanFallback>());
    });
  });

  group('parseReceiptJson', () {
    test('parses clean JSON', () {
      final parsed = parseReceiptJson(
        '{"vendor":"Store","date":"2024-06-01","total":10.5}',
        fallback,
      );
      expect(parsed?.vendor, 'Store');
      expect(parsed?.total, 10.5);
      expect(parsed?.date, DateTime(2024, 6, 1));
    });

    test('strips markdown fences', () {
      final parsed = parseReceiptJson(
        '```json\n{"vendor":"A","date":"2024-01-01","total":1}\n```',
        fallback,
      );
      expect(parsed?.vendor, 'A');
      expect(parsed?.total, 1);
    });
  });

}
