import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';

void main() {
  group('receiptScanModeFromLegacy', () {
    test('AI + gemini → cloud', () {
      expect(
        receiptScanModeFromLegacy(
          ocrEnabled: false,
          aiEnabled: true,
          provider: 'gemini',
        ),
        'cloud',
      );
    });

    test('OCR on AI off → local', () {
      expect(
        receiptScanModeFromLegacy(
          ocrEnabled: true,
          aiEnabled: false,
          provider: 'none',
        ),
        'local',
      );
    });

    test('both off → off', () {
      expect(
        receiptScanModeFromLegacy(
          ocrEnabled: false,
          aiEnabled: false,
          provider: 'none',
        ),
        'off',
      );
    });

    test('AI on provider none + OCR → local', () {
      expect(
        receiptScanModeFromLegacy(
          ocrEnabled: true,
          aiEnabled: true,
          provider: 'none',
        ),
        'local',
      );
    });
  });
}
