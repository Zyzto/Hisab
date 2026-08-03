import 'package:flutter/services.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';

import 'receipt_scan_cancel.dart';

const _channel = MethodChannel('hisab/receipt_ocr');

/// Run on-device OCR (Android Tesseract / iOS Vision).
Future<String> recognizeReceiptText(
  String imagePath, {
  ReceiptScanCancelToken? cancel,
}) async {
  cancel?.throwIfCancelled();
  try {
    final text = await _channel.invokeMethod<String>('recognize', {
      'path': imagePath,
      'languages': 'eng+ara',
    });
    cancel?.throwIfCancelled();
    return (text ?? '').trim();
  } on PlatformException catch (e) {
    if (e.code == 'cancelled' || cancel?.isCancelled == true) {
      throw const ReceiptScanCancelledException();
    }
    Log.error('Receipt OCR platform error: ${e.code} ${e.message}');
    rethrow;
  }
}

/// Ask native OCR to stop (TessBaseAPI.stop / Vision cancel).
Future<void> cancelReceiptOcr() async {
  try {
    await _channel.invokeMethod<void>('cancel');
  } on PlatformException catch (e) {
    Log.debug('Receipt OCR cancel: ${e.code} ${e.message}');
  } catch (e) {
    Log.debug('Receipt OCR cancel failed: $e');
  }
}
