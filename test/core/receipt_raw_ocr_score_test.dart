import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/receipt_ocr_expectations.dart';

/// Scores extractor against committed noisy Tesseract output fixtures.
void main() {
  final ocrDir = Directory('test/fixtures/receipts/ocr_raw');

  test('raw OCR score for fixture samples', () {
    expect(ocrDir.existsSync(), isTrue, reason: '${ocrDir.path} missing');

    final result = scoreOcrDir(ocrDir);

    // ignore: avoid_print
    print(result.report.join('\n'));
    // ignore: avoid_print
    print('RAW_SCORE ${result.hits}/${result.checks}');

    expect(result.checks, greaterThan(0));
    expect(result.ratio, greaterThanOrEqualTo(0.95));
  });
}
