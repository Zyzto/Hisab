import 'package:flutter/foundation.dart';

/// Whether the OS screenshot → report prompt is offered in Settings.
///
/// Detection is only wired for native iOS and Android (14+ at runtime).
/// Web and desktop are unsupported.
bool get supportsScreenshotReportPrompt {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
}
