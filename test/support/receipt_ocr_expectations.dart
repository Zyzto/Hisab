import 'dart:io';

import 'package:hisab/core/receipt/receipt_local_extractor.dart';

/// Expected store/total/VAT for the shared 8-sample receipt set.
///
/// Fixture ids match filenames under [test/fixtures/receipts/ocr_raw/]
/// (noisy OCR) and are also used when scoring local scratch dirs.
const receiptOcrExpectations =
    <(String id, String store, double total, double? vat)>[
      ('20250130_203910', 'ASIAN', 150.65, 19.65),
      ('٢٠٢٥٠٨١٨_١٤٠٥٠٩', 'SUSHI', 264.0, 34.43),
      ('٢٠٢٦٠١١٤_١٥١٧٥٥', 'SPL', 172.0, 2.4),
      ('٢٠٢٦٠١٢٠_١٤٢٧١٤', 'LAZA', 189.0, 24.65),
      ('٢٠٢٦٠١٢٠_٢٠١٦٤٧', 'Casa', 94.0, 12.26),
      ('٢٠٢٦٠٥٢٢_٠٧٢٩٣١', 'Family', 51.45, 2.73),
      ('texas_simple', 'Texas', 162.0, 21.13),
      ('IMG_20210508_140021', 'extra', 1899.0, null),
    ];

class ReceiptOcrScoreResult {
  const ReceiptOcrScoreResult({
    required this.hits,
    required this.checks,
    required this.report,
  });

  final int hits;
  final int checks;
  final List<String> report;

  double get ratio => checks == 0 ? 0 : hits / checks;
}

/// Scores [dir] of `*.txt` OCR dumps against [receiptOcrExpectations].
ReceiptOcrScoreResult scoreOcrDir(Directory dir, {DateTime? fallbackDate}) {
  final fb = fallbackDate ?? DateTime(2020, 1, 1);
  var hits = 0;
  var checks = 0;
  final report = <String>[];

  for (final e in receiptOcrExpectations) {
    final file = File('${dir.path}/${e.$1}.txt');
    if (!file.existsSync()) {
      report.add('MISSING ${e.$1}');
      continue;
    }
    final raw = file.readAsStringSync();
    final d = extractReceiptDetails(raw, fb);
    final storeOk = d.store.toLowerCase().contains(e.$2.toLowerCase());
    final totalOk = d.total != null && (d.total! - e.$3).abs() < 0.51;
    // Only require VAT when the OCR text actually contains a tax cue/value.
    final vatInOcr =
        e.$4 == null ||
        raw.contains(e.$4!.toStringAsFixed(2)) ||
        RegExp(r'\b(VAT|VTA|SST|ضريبة)\b', caseSensitive: false).hasMatch(raw);
    final vatOk =
        e.$4 == null ||
        !vatInOcr ||
        (d.vat != null && (d.vat! - e.$4!).abs() < 0.51);
    checks += 3;
    if (storeOk) hits++;
    if (totalOk) hits++;
    if (vatOk) hits++;
    report.add(
      '${e.$1}: store=${d.store}(${storeOk ? "Y" : "N"}) '
      'total=${d.total}(${totalOk ? "Y" : "N"}) '
      'vat=${d.vat}(${vatOk ? "Y" : "N"})',
    );
  }

  return ReceiptOcrScoreResult(hits: hits, checks: checks, report: report);
}
