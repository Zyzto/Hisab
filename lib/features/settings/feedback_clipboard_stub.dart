import 'package:clipboard/clipboard.dart';
import 'package:flutter/services.dart';

/// Non-web: use clipboard package copyMultiple (platform channel supports text+image).
Future<void> setFeedbackClipboard(String body, Uint8List? screenshotPng) async {
  final formats = <String, dynamic>{'text/plain': body};
  if (screenshotPng != null && screenshotPng.isNotEmpty) {
    formats['image/png'] = screenshotPng;
  }
  try {
    await FlutterClipboard.copyMultiple(formats);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: body));
  }
}
