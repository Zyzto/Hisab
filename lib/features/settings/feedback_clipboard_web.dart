import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// On web: writes both body and screenshot to clipboard so paste includes image.
/// The clipboard package's copyMultiple uses platform channel and falls back to text-only on web.
Future<void> setFeedbackClipboard(String body, Uint8List? screenshotPng) async {
  if (screenshotPng == null || screenshotPng.isEmpty) {
    await Clipboard.setData(ClipboardData(text: body));
    return;
  }
  try {
    final imageBlob = web.Blob(
      [screenshotPng.buffer.toJS].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );
    final items = JSObject();
    items.setProperty('text/plain'.toJS, body.toJS);
    items.setProperty('image/png'.toJS, imageBlob);
    final item = web.ClipboardItem(items);
    await web.window.navigator.clipboard.write([item].toJS).toDart;
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: body));
  }
}
