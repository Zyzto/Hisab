import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/receipt/receipt_scan_capability.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android offers nano in available modes', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      ReceiptScanCapability.availableModes(),
      contains(ReceiptScanMode.nano),
    );
    expect(ReceiptScanCapability.supportsNano, isTrue);
    expect(ReceiptScanCapability.supportsOcr, isTrue);
  });

  test('iOS does not offer nano; nano coerces to local', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      ReceiptScanCapability.availableModes(),
      isNot(contains(ReceiptScanMode.nano)),
    );
    expect(ReceiptScanCapability.supportsNano, isFalse);
    expect(
      ReceiptScanCapability.effectiveMode(ReceiptScanMode.nano),
      ReceiptScanMode.local,
    );
    expect(
      ReceiptScanCapability.scanUiEnabled(ReceiptScanMode.nano),
      isTrue,
    );
  });

  test('off disables scan UI on native', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      ReceiptScanCapability.scanUiEnabled(ReceiptScanMode.off),
      isFalse,
    );
  });

  test('iOS still enables scan UI when stored mode is nano (coerced to local)', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      ReceiptScanCapability.scanUiEnabled(ReceiptScanMode.nano),
      isTrue,
    );
    expect(
      ReceiptScanCapability.effectiveMode(ReceiptScanMode.nano),
      isNot(ReceiptScanMode.nano),
    );
  });
}
