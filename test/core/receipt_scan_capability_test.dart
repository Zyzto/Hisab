import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/receipt/receipt_scan_capability.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android offers local OCR in available modes', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      ReceiptScanCapability.availableModes(),
      contains(ReceiptScanMode.local),
    );
    expect(ReceiptScanCapability.supportsOcr, isTrue);
  });

  test('iOS offers local OCR', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      ReceiptScanCapability.availableModes(),
      contains(ReceiptScanMode.local),
    );
  });

  test('off disables scan UI on native', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(ReceiptScanCapability.scanUiEnabled(ReceiptScanMode.off), isFalse);
  });
}
