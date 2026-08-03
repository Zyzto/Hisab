// Score OCR text folders with Hisab's receipt extractor.
// Usage: dart run tool/score_ocr_dirs.dart <label=dir> [label=dir ...]
// Example: dart run tool/score_ocr_dirs.dart ocr2=tmp/receipts/ocr2
import 'dart:io';

import '../test/support/receipt_ocr_expectations.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/score_ocr_dirs.dart label=dir ...');
    exit(2);
  }
  final fb = DateTime(2020, 1, 1);
  for (final arg in args) {
    final eq = arg.indexOf('=');
    if (eq <= 0) continue;
    final label = arg.substring(0, eq);
    final dir = Directory(arg.substring(eq + 1));
    stdout.writeln('=== $label (${dir.path}) ===');
    final result = scoreOcrDir(dir, fallbackDate: fb);
    for (final line in result.report) {
      stdout.writeln(line);
    }
    // optional crushed phone texas
    final phone = File('${dir.path}/texas_phone_crushed.txt');
    if (phone.existsSync()) {
      // Keep ad-hoc sample outside the shared 8-set.
      // ignore: avoid_print — CLI tool
      stdout.writeln('(also found texas_phone_crushed.txt — not in shared set)');
    }
    stdout.writeln('SCORE $label ${result.hits}/${result.checks}\n');
  }
}
