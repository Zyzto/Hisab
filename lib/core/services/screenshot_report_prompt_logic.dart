import 'package:flutter/foundation.dart';

/// Pure debounce / gate logic for the screenshot → report prompt.
class ScreenshotReportPromptLogic {
  ScreenshotReportPromptLogic({
    this.debounce = const Duration(seconds: 5),
  });

  final Duration debounce;
  DateTime? _lastPromptAt;

  /// Returns true when a prompt should be shown and records the attempt time.
  ///
  /// [appInForeground] should be true for [AppLifecycleState.resumed] and
  /// [AppLifecycleState.inactive] (iOS briefly goes inactive during screenshots).
  bool shouldPrompt({
    required bool enabled,
    required bool appInForeground,
    required bool feedbackOpen,
    DateTime? now,
  }) {
    if (!enabled || !appInForeground || feedbackOpen) return false;
    final at = now ?? DateTime.now();
    final last = _lastPromptAt;
    if (last != null && at.difference(last) < debounce) return false;
    _lastPromptAt = at;
    return true;
  }

  @visibleForTesting
  void reset() => _lastPromptAt = null;
}
