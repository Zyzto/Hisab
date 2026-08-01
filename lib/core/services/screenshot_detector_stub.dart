/// No-op detector for web (and tests without a native plugin).
class ScreenshotDetector {
  ScreenshotDetector();

  Stream<void> get events => const Stream<void>.empty();

  Future<void> setEnabled(bool enabled) async {}
}

ScreenshotDetector createScreenshotDetector() => ScreenshotDetector();
