import 'models.dart';

/// Reachability probe backing the in-app service status sheet.
abstract interface class CloudHealth {
  /// Checks whether the backend is answering. Must not throw: connectivity
  /// failures are reported as [CloudHealthStatus.unreachable].
  ///
  /// Distinguishing [CloudHealthStatus.paused] from `unreachable` matters
  /// because a paused backend is the operator's problem to fix, and the app
  /// tells the user so instead of blaming their connection.
  Future<CloudHealthResult> probe();
}
