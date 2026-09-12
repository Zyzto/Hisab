import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';

void main() {
  group('receiptScanModeFromLegacy', () {
    test('OCR on → local', () {
      expect(receiptScanModeFromLegacy(ocrEnabled: true), 'local');
    });

    test('both off → off', () {
      expect(receiptScanModeFromLegacy(ocrEnabled: false), 'off');
    });
  });
}
