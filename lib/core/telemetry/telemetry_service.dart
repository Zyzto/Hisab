import 'package:hisab_backend/hisab_backend.dart';

/// Sends opt-in diagnostics through whatever backend is registered.
///
/// A no-op offline, when the backend declines telemetry, or when the user has
/// not opted in. Never throws: dropping an event is always preferable to
/// interrupting whatever the user was doing.
class TelemetryService {
  /// [enabled] comes from settings (`telemetryEnabledProvider`).
  static Future<void> sendEvent(
    String name,
    Map<String, dynamic>? data, {
    required bool enabled,
  }) async {
    if (!enabled) return;
    final telemetry = cloudBackend?.telemetry;
    if (telemetry == null || !telemetry.isEnabled) return;

    await telemetry.send({
      'event': name,
      'timestamp': DateTime.now().toIso8601String(),
      if (data != null) 'data': data,
    });
  }
}
