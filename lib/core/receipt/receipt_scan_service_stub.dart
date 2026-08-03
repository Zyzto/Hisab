import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'receipt_scan_cancel.dart';
import 'receipt_scan_types.dart';

export 'receipt_scan_cancel.dart';
export 'receipt_scan_types.dart';

/// Web: receipt OCR/AI is unsupported (Tesseract/Vision/LLM not wired for web).
Future<ReceiptScanResult?> processReceiptFile(
  XFile file,
  WidgetRef ref,
  DateTime fallbackDate, {
  ReceiptScanCancelToken? cancel,
}) async =>
    null;

/// Web: receipt OCR/AI is unsupported.
Future<ReceiptScanResult?> processReceiptBytes(
  Uint8List bytes,
  WidgetRef ref,
  DateTime fallbackDate, {
  ReceiptScanCancelToken? cancel,
}) async =>
    null;

/// Web: Nano never needs attention (scan UI hidden).
Future<bool> nanoNeedsUserAttention(WidgetRef ref) async => false;
