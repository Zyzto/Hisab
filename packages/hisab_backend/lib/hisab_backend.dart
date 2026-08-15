/// The contract between the Hisab app and a cloud backend.
///
/// The app depends only on this package. A backend is a separate package that
/// implements [CloudBackend] and registers itself at startup; swapping backends
/// is a `dependency_overrides` change, not a code change.
///
/// See `README.md` for the full specification and `docs/SELF_HOSTING.md` in the
/// app repo for a walkthrough of building your own.
library;

export 'src/auth_redirect.dart';
export 'src/cloud_account.dart';
export 'src/cloud_auth.dart';
export 'src/cloud_backend.dart';
export 'src/cloud_files.dart';
export 'src/cloud_groups.dart';
export 'src/cloud_health.dart';
export 'src/cloud_invites.dart';
export 'src/cloud_notifications.dart';
export 'src/cloud_sync.dart';
export 'src/cloud_telemetry.dart';
export 'src/models.dart';
