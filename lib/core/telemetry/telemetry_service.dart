import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:http/http.dart' as http;

import '../constants/app_config.dart';

/// Telemetry service. Sends events to a configurable endpoint.
/// No-op when [telemetryEndpointUrl] is empty or [enabled] is false.
/// Swallows all errors; never throws.
class TelemetryService {
  /// Send an event. Fire-and-forget; errors are swallowed.
  /// [enabled] should come from settings (telemetryEnabledProvider).
  static Future<void> sendEvent(
    String name,
    Map<String, dynamic>? data, {
    required bool enabled,
  }) async {
    if (!enabled || telemetryEndpointUrl.isEmpty) return;

    try {
      final body = jsonEncode({
        'event': name,
        'timestamp': DateTime.now().toIso8601String(),
        ...?data != null ? {'data': data} : null,
      });
      final response = await http
          .post(
            Uri.parse(telemetryEndpointUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 400 && kDebugMode) {
        Log.debug('Telemetry send failed: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        Log.debug('Telemetry send error: $e');
      }
    }
  }
}
