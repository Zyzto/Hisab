import 'package:flutter/foundation.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:http/http.dart' as http;

/// Result of fetching a URL with timeout. [body] is set on 200; [error] on failure.
typedef FetchUrlResult = ({String? body, String? error});

const Duration _defaultTimeout = Duration(seconds: 10);

/// Fetches [url] with GET and [timeout]. Returns body on 200, otherwise error message.
/// Logs on failure. Use for status pages, APIs, etc.
Future<FetchUrlResult> fetchUrlWithTimeout(
  Uri url, {
  Duration timeout = _defaultTimeout,
}) async {
  try {
    final response = await http.get(url).timeout(timeout);
    if (response.statusCode != 200) {
      if (kDebugMode) {
        Log.warning('HTTP fetch $url: ${response.statusCode}');
      }
      return (body: null, error: 'HTTP ${response.statusCode}');
    }
    return (body: response.body, error: null);
  } catch (e, st) {
    if (kDebugMode) {
      Log.error('HTTP fetch $url failed', error: e, stackTrace: st);
    }
    return (body: null, error: e.toString());
  }
}
