import 'package:flutter/services.dart';

/// Sets clipboard to feedback body (text). Screenshot is ignored on non-web.
Future<void> setFeedbackClipboard(String body, Uint8List? screenshotPng) async {
  await Clipboard.setData(ClipboardData(text: body));
}
