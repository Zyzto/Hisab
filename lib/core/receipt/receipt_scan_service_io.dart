import 'dart:async';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/settings/providers/settings_framework_providers.dart';
import 'receipt_ai_backend.dart';
import 'receipt_local_extractor.dart';
import 'receipt_nano_service.dart';
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
const _nanoStatusTimeout = Duration(seconds: 3);
const _cloudTimeout = Duration(seconds: 45);

Future<T> _withTimeout<T>(
  Future<T> future,
  Duration timeout,
  String label,
) {
  return future.timeout(
    timeout,
    onTimeout: () {
      Log.warning('Receipt scan timeout: $label after ${timeout.inSeconds}s');
      throw TimeoutException('Receipt scan timed out: $label');
    },
  );
}

Future<String> _runOcr(
  XFile file,
  ReceiptScanCancelToken? cancel,
) async {
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

/// Process a receipt image file: local / nano / cloud pipeline (native only).
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

    if (mode == ReceiptScanMode.nano) {
      final ocrText = await _runOcr(file, cancel);
      cancel?.throwIfCancelled();
      Log.debug('Receipt scan: Nano status check…');
      NanoFeatureStatus status;
      try {
        status = await _withTimeout(
          checkNanoStatus(),
          _nanoStatusTimeout,
          'nano_status',
        );
      } on TimeoutException {
        status = NanoFeatureStatus.unavailable;
      }
      cancel?.throwIfCancelled();
      Log.debug('Receipt scan: Nano status=$status');
      if (status == NanoFeatureStatus.available) {
        final raw = await _withTimeout(
          extractReceiptJsonWithNano(
            ocrText: ocrText.isNotEmpty ? ocrText : null,
            imagePath: ocrText.isEmpty ? file.path : null,
          ),
          _cloudTimeout,
          'nano_infer',
        );
        cancel?.throwIfCancelled();
        if (raw != null) {
          final parsed = parseReceiptJson(raw, fallbackDate);
          if (parsed != null) {
            Log.info(
              'Receipt scan nano parsed: vendor="${parsed.vendor}" total=${parsed.total}',
            );
            return ReceiptScanParsed(
              vendor: parsed.vendor.isNotEmpty
                  ? parsed.vendor
                  : 'receipt_fallback_vendor'.tr(),
              date: parsed.date,
              total: parsed.total,
              vat: parsed.vat,
              lineItems: parsed.lineItems,
              description: parsed.description,
            );
          }
        }
        Log.debug('Receipt scan: Nano parse failed, falling back to local');
      } else {
        Log.debug('Receipt scan: Nano not available ($status), local fallback');
      }
      if (ocrText.isEmpty) return null;
      final storedPath = await copyReceiptToAppStorage(file.path);
      return _localFromOcr(ocrText, fallbackDate, storedPath);
    }

    if (mode == ReceiptScanMode.cloud) {
      final provider = ref.read(receiptAiProviderProvider);
      final geminiKey = ref.read(geminiApiKeyProvider);
      final openaiKey = ref.read(openaiApiKeyProvider);
      final backend = receiptAiBackendForProvider(
        provider,
        geminiKey,
        openaiKey,
      );

      if (backend != null) {
        try {
          cancel?.throwIfCancelled();
          Log.debug('Receipt scan: cloud invoke provider=$provider');
          final imageBytes = await file.readAsBytes();
          cancel?.throwIfCancelled();
          final responseText = await _withTimeout(
            backend.extractRawJson(imageBytes),
            _cloudTimeout,
            'cloud_$provider',
          );
          cancel?.throwIfCancelled();
          final parsed = parseReceiptJson(responseText, fallbackDate);
          if (parsed != null) {
            Log.info(
              'Receipt scan cloud parsed: vendor="${parsed.vendor}" total=${parsed.total}',
            );
            return ReceiptScanParsed(
              vendor: parsed.vendor.isNotEmpty
                  ? parsed.vendor
                  : 'receipt_fallback_vendor'.tr(),
              date: parsed.date,
              total: parsed.total,
              vat: parsed.vat,
              lineItems: parsed.lineItems,
              description: parsed.description,
            );
          }
          Log.debug('Receipt scan: cloud parse failed, OCR+local fallback');
        } on ReceiptScanCancelledException {
          rethrow;
        } catch (e) {
          Log.debug('Receipt scan: cloud failed, OCR+local fallback: $e');
        }
      } else {
        Log.debug('Receipt scan: cloud not configured, OCR+local fallback');
      }

      cancel?.throwIfCancelled();
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

/// True when user selected Nano but it can't run (for one-shot UI toast).
Future<bool> nanoNeedsUserAttention(WidgetRef ref) async {
  final stored = ref.read(receiptScanModeProvider);
  if (stored != ReceiptScanMode.nano) return false;
  if (!ReceiptScanCapability.supportsNano) return true;
  try {
    final status = await checkNanoStatus().timeout(_nanoStatusTimeout);
    return status != NanoFeatureStatus.available;
  } on TimeoutException {
    Log.warning('Receipt scan: Nano status timed out during attention check');
    return true;
  }
}
