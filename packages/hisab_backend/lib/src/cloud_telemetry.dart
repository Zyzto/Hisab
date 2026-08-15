/// Optional, opt-in diagnostics sink.
abstract interface class CloudTelemetry {
  /// Whether this backend accepts telemetry at all. When false the app skips
  /// collection entirely rather than buffering events nobody will read.
  bool get isEnabled;

  /// Fire-and-forget. Must never throw and must never block a user action;
  /// dropping an event is always preferable to surfacing an error.
  Future<void> send(Map<String, dynamic> payload);
}
