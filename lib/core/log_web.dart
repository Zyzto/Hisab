import 'package:flutter/foundation.dart';

/// On web, holds the last [maxLines] lines written via [debugPrint]
/// so the View Logs dialog can show them instead of "open console".
const int _kWebLogMaxLines = 500;

final List<String> _webLogLines = [];
bool _webLogCaptureInitialized = false;

/// Skip known noisy web lines so they don't clutter the View Logs modal.
bool _shouldSkipLine(String line) {
  return line.contains('LegacyJavaScriptObject') &&
      line.contains('UpdateNotification');
}

/// ANSI escape sequences (e.g. [32m, [0m) from console/logger output so
/// View Logs shows plain text like the debug console.
String _stripAnsiEscapes(String line) {
  return line.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
}

void _captureLine(String line) {
  final stripped = _stripAnsiEscapes(line).trim();
  if (stripped.isEmpty) return;
  if (_shouldSkipLine(stripped)) return;
  // Skip consecutive duplicates (e.g. same line from both debugPrint and print).
  if (_webLogLines.isNotEmpty && _webLogLines.last == stripped) return;
  if (_webLogLines.length >= _kWebLogMaxLines) {
    _webLogLines.removeAt(0);
  }
  _webLogLines.add(stripped);
}

/// Captures a line from [print] on web. Used by the Zone in [main] so that
/// EasyLogger (and any other code using [print]) appears in the View Logs dialog.
/// Same filtering and cap as [debugPrint] capture. Call only when [kIsWeb].
void capturePrintLine(String line) {
  if (line.isEmpty) return;
  _captureLine(line);
}

/// Call from [main] when [kIsWeb] to capture console output for the View Logs dialog.
void initWebLogCapture() {
  if (_webLogCaptureInitialized) return;
  _webLogCaptureInitialized = true;
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && message.isNotEmpty) {
      _captureLine(message);
    }
    original(message, wrapWidth: wrapWidth);
  };
}

/// Returns captured log lines for web. Call only when [kIsWeb].
String getWebLogContent() {
  if (_webLogLines.isEmpty) {
    return '';
  }
  return _webLogLines.join('\n');
}

/// Clears the in-memory web log buffer (e.g. when user taps Clear in View Logs).
void clearWebLogContent() {
  _webLogLines.clear();
}
