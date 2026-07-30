import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'receipt_scan_types.dart';

export 'receipt_scan_types.dart';

/// Web: receipt OCR/AI is unsupported (ML Kit + LLM stack not wired for web).
Future<ReceiptScanResult?> processReceiptFile(
  XFile file,
  WidgetRef ref,
  DateTime fallbackDate,
) async =>
    null;

/// Web: receipt OCR/AI is unsupported.
Future<ReceiptScanResult?> processReceiptBytes(
  Uint8List bytes,
  WidgetRef ref,
  DateTime fallbackDate,
) async =>
    null;
