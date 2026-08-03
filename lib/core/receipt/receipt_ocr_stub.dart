import 'receipt_scan_cancel.dart';

/// Web: OCR unsupported.
Future<String> recognizeReceiptText(
  String imagePath, {
  ReceiptScanCancelToken? cancel,
}) async =>
    '';

/// Web: no-op.
Future<void> cancelReceiptOcr() async {}
