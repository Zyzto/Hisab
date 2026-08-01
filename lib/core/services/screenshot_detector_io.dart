import 'package:flutter/foundation.dart';
import 'package:ss_preventer/ss_preventer.dart';

import '../platform/screenshot_report_support.dart';

/// Native detector via [SsPreventer] (iOS + Android 14+). Never enables prevention.
class ScreenshotDetector {
  ScreenshotDetector();

  Stream<void> get events =>
      SsPreventer.screenshotStream.map((_) {});

  Future<void> setEnabled(bool enabled) async {
    if (!supportsScreenshotReportPrompt) return;
    try {
      await SsPreventer.setDetectionEnabled(enabled);
    } catch (e, st) {
      debugPrint('ScreenshotDetector.setEnabled failed: $e\n$st');
    }
  }
}

ScreenshotDetector createScreenshotDetector() => ScreenshotDetector();
