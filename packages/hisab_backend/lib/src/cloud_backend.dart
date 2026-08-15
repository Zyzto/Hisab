import 'cloud_account.dart';
import 'cloud_auth.dart';
import 'cloud_files.dart';
import 'cloud_groups.dart';
import 'cloud_health.dart';
import 'cloud_invites.dart';
import 'cloud_notifications.dart';
import 'cloud_sync.dart';
import 'cloud_telemetry.dart';

/// Everything Hisab needs from a server.
///
/// A build either has one of these or runs fully offline; there is no partial
/// mode. Implement all nine facets, then call [registerCloudBackend] from your
/// package's entry point.
abstract interface class CloudBackend {
  CloudAuth get auth;
  CloudSync get sync;
  CloudGroups get groups;
  CloudInvites get invites;
  CloudNotifications get notifications;
  CloudFiles get files;
  CloudAccount get account;
  CloudTelemetry get telemetry;
  CloudHealth get health;

  /// Prepares the backend for use: restores a persisted session, opens
  /// connections, starts listeners. Called once during app startup, before the
  /// first frame.
  Future<void> initialize();

  /// Releases connections and listeners. Only used by tests.
  Future<void> dispose();
}

CloudBackend? _registered;

/// Installs [backend] as the app's cloud provider.
///
/// Call this from your `registerHisabCloud()` before `runApp`. Registering
/// twice replaces the previous backend, which tests rely on.
void registerCloudBackend(CloudBackend backend) {
  _registered = backend;
}

/// Removes the registered backend, returning the app to offline behaviour.
void clearCloudBackend() {
  _registered = null;
}

/// The registered backend, or null in an offline build.
CloudBackend? get cloudBackend => _registered;

/// Whether this build has a cloud backend.
///
/// Every online-only affordance in the UI is gated on this. In an offline
/// build it is false for the whole process lifetime, so the compiler and the
/// tree shaker can both see the online paths are dead.
bool get cloudAvailable => _registered != null;
