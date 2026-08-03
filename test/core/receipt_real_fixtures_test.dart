import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/receipt/receipt_local_extractor.dart';

typedef _Expect = ({
  String storeContains,
  double total,
  double? vat,
  DateTime date,
  int? minItems,
  List<String>? itemContains,
});

void main() {
  final fallback = DateTime(2020, 1, 1);
  final dir = Directory('test/fixtures/receipts');

  String read(String name) => File('${dir.path}/$name').readAsStringSync();

  final cases = <String, _Expect>{
    'asian_foods.txt': (
      storeContains: 'ASIAN FOODS',
      total: 150.65,
      vat: 19.65,
      date: DateTime(2025, 1, 30, 20, 36, 44),
      minItems: 5,
      itemContains: ['TomYam', 'TEMPURA', 'ICE TEA'],
    ),
    'sushiart.txt': (
      storeContains: 'SUSHIART',
      total: 264.00,
      vat: 34.43,
      date: DateTime(2025, 8, 18),
      minItems: 2,
      itemContains: ['Sushi', 'Juice'],
    ),
    'spl_post.txt': (
      storeContains: 'SPL',
      total: 172.00,
      vat: 2.40,
      date: DateTime(2026, 1, 14, 15, 15),
      minItems: 2,
      itemContains: ['طرد', 'تغليف'],
    ),
    'laza.txt': (
      storeContains: 'LAZA',
      total: 189.00,
      vat: 24.65,
      date: DateTime(2026, 1, 20, 13, 38, 59),
      minItems: 1,
      itemContains: ['PLOV'],
    ),
    'lacasa.txt': (
      storeContains: 'La Casa',
      total: 94.00,
      vat: 12.26,
      date: DateTime(2026, 1, 20, 20, 14, 5),
      minItems: 3,
      itemContains: ['Penne', 'orange'],
    ),
    'familymart.txt': (
      storeContains: 'FamilyMart',
      total: 51.45,
      vat: 2.73,
      date: DateTime(2026, 5, 21, 21, 17),
      minItems: 8,
      itemContains: ['Oden', 'Kirin', 'Onigiri'],
    ),
    'texas.txt': (
      storeContains: 'Texas',
      total: 162.00,
      vat: 21.13,
      date: DateTime(2026, 6, 15, 13, 48),
      minItems: 3,
      itemContains: ['FRCATCH', 'Buff'],
    ),
    'extra.txt': (
      storeContains: 'extra',
      total: 1899.00,
      vat: null,
      date: DateTime(2020, 1, 1), // no date on cropped slip — keep fallback
      minItems: 1,
      itemContains: ['Dishwasher'],
    ),
  };

  for (final entry in cases.entries) {
    test('fixture ${entry.key}', () {
      final e = entry.value;
      final details = extractReceiptDetails(read(entry.key), fallback);

      expect(
        details.store.toLowerCase(),
        contains(e.storeContains.toLowerCase()),
        reason: 'store="${details.store}"',
      );
      expect(details.total, closeTo(e.total, 0.011), reason: 'total');
      if (e.vat != null) {
        expect(details.vat, closeTo(e.vat!, 0.011), reason: 'vat');
      }
      if (entry.key != 'extra.txt') {
        expect(details.dateTime.year, e.date.year);
        expect(details.dateTime.month, e.date.month);
        expect(details.dateTime.day, e.date.day);
        if (e.date.hour != 0 || e.date.minute != 0) {
          expect(details.dateTime.hour, e.date.hour);
          expect(details.dateTime.minute, e.date.minute);
        }
      }
      if (e.minItems != null) {
        expect(
          details.items.length,
          greaterThanOrEqualTo(e.minItems!),
          reason: 'items=${details.items.map((i) => i.description).toList()}',
        );
      }
      for (final needle in e.itemContains ?? const <String>[]) {
        expect(
          details.items.any(
            (i) => i.description.toLowerCase().contains(needle.toLowerCase()),
          ),
          isTrue,
          reason:
              'missing item "$needle" in ${details.items.map((i) => i.description).toList()}',
        );
      }
      expect(details.description, isNotNull);
    });
  }
}
