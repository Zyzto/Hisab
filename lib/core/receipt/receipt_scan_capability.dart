import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Stored scan mode values for the local receipt scanner.
abstract final class ReceiptScanMode {
  static const off = 'off';
  static const local = 'local';

  static const all = <String>[off, local];
}

/// Platform capabilities for receipt scan / AI (Android, iOS, web).
///
/// Uses [kIsWeb] / [defaultTargetPlatform] so shared UI can import this
/// without `dart:io`.
abstract final class ReceiptScanCapability {
  static bool get isNativeMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// On-device OCR + heuristics (Tesseract Android / Vision iOS).
  static bool get supportsOcr => isNativeMobile;

  /// Modes offered in the settings picker on this platform.
  static List<String> availableModes() {
    if (kIsWeb) return const [ReceiptScanMode.off];
    final modes = <String>[ReceiptScanMode.off, ReceiptScanMode.local];
    return modes;
  }

  /// Coerce a stored mode to what this platform can actually run for a scan.
  /// Does not rewrite prefs — only effective runtime behavior.
  static String effectiveMode(String storedMode) {
    if (kIsWeb) return ReceiptScanMode.off;
    switch (storedMode) {
      case ReceiptScanMode.off:
        return ReceiptScanMode.off;
      case ReceiptScanMode.local:
        return supportsOcr ? ReceiptScanMode.local : ReceiptScanMode.off;
      default:
        return ReceiptScanMode.off;
    }
  }

  /// Whether scan UI (button / long-press / auto-scan) should show.
  static bool scanUiEnabled(String storedMode) {
    final mode = effectiveMode(storedMode);
    return isNativeMobile && mode != ReceiptScanMode.off;
  }
}
