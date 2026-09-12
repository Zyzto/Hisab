import 'dart:async';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../settings/providers/settings_framework_providers.dart';
import 'receipt_local_extractor.dart';
import 'receipt_ocr.dart';
import 'receipt_scan_cancel.dart';
import 'receipt_scan_capability.dart';
import 'receipt_scan_types.dart';
import 'receipt_storage.dart';
import 'receipt_temp_file.dart';

export 'receipt_scan_cancel.dart';
export 'receipt_scan_types.dart';

// Multi-PSM × preprocess variants on midrange phones often needs >20s.
const _ocrTimeout = Duration(seconds: 55);

Future<T> _withTimeout<T>(Future<T> future, Duration timeout, String label) {
  return future.timeout(
    timeout,
    onTimeout: () {
      Log.warning('Receipt scan timeout: $label after ${timeout.inSeconds}s');
      throw TimeoutException('Receipt scan timed out: $label');
    },
  );
}

Future<String> _runOcr(XFile file, ReceiptScanCancelToken? cancel) async {
  cancel?.throwIfCancelled();
  Log.debug('Receipt scan: OCR start path=${file.path}');
  try {
    final text = await _withTimeout(
      recognizeReceiptText(file.path, cancel: cancel),
      _ocrTimeout,
      'ocr',
    );
    cancel?.throwIfCancelled();
    final preview = text.length <= 220
        ? text
        : '${text.substring(0, 220).replaceAll('\n', ' ')}…';
    Log.debug('Receipt scan: OCR done chars=${text.length} preview="$preview"');
    return text;
  } on TimeoutException {
    await cancelReceiptOcr();
    rethrow;
  }
}

Future<ReceiptScanResult> _localFromOcr(
  String ocrText,
  DateTime fallbackDate,
  String? storedPath,
) async {
  final extracted = extractReceiptFromOcrText(ocrText, fallbackDate);
  switch (extracted) {
    case ReceiptScanParsed():
      Log.info(
        'Receipt scan local parsed: vendor="${extracted.vendor}" '
        'total=${extracted.total} vat=${extracted.vat} '
        'items=${extracted.lineItems?.length ?? 0}',
      );
      return ReceiptScanParsed(
        vendor: extracted.vendor.isNotEmpty
            ? extracted.vendor
            : 'receipt_fallback_vendor'.tr(),
        date: extracted.date,
        total: extracted.total,
        vat: extracted.vat,
        lineItems: extracted.lineItems,
        description: extracted.description,
      );
    case ReceiptScanFallback():
      Log.debug('Receipt scan local fallback (no total)');
      return ReceiptScanFallback(
        ocrText: ocrText,
        receiptImagePath: storedPath,
      );
  }
}

/// Process a receipt image file using local OCR.
Future<ReceiptScanResult?> processReceiptFile(
  XFile file,
  WidgetRef ref,
  DateTime fallbackDate, {
  ReceiptScanCancelToken? cancel,
}) async {
  try {
    cancel?.throwIfCancelled();
    final storedMode = ref.read(receiptScanModeProvider);
    final mode = ReceiptScanCapability.effectiveMode(storedMode);
    Log.info('Receipt scan start mode=$storedMode effective=$mode');

    if (mode == ReceiptScanMode.off) {
      Log.debug('Receipt scan: mode off, attach-only path');
      final storedPath = await copyReceiptToAppStorage(file.path);
      return ReceiptScanFallback(ocrText: '', receiptImagePath: storedPath);
    }

    if (mode == ReceiptScanMode.local) {
      final ocrText = await _runOcr(file, cancel);
      cancel?.throwIfCancelled();
      if (ocrText.isEmpty) return null;
      final storedPath = await copyReceiptToAppStorage(file.path);
      return _localFromOcr(ocrText, fallbackDate, storedPath);
    }

    return null;
  } on ReceiptScanCancelledException {
    Log.info('Receipt scan cancelled');
    rethrow;
  } catch (e, st) {
    Log.error('Receipt scan failed', error: e, stackTrace: st);
    rethrow;
  }
}

/// Process receipt from in-memory bytes (native only).
Future<ReceiptScanResult?> processReceiptBytes(
  Uint8List bytes,
  WidgetRef ref,
  DateTime fallbackDate, {
  ReceiptScanCancelToken? cancel,
}) async {
  cancel?.throwIfCancelled();
  Log.debug('Receipt scan: write temp bytes=${bytes.length}');
  final path = await writeReceiptBytesToTempFile(bytes);
  if (path == null) return null;
  cancel?.throwIfCancelled();
  return processReceiptFile(XFile(path), ref, fallbackDate, cancel: cancel);
}
