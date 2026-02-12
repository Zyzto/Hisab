/// Template for app_secrets.dart. Copy to app_secrets.dart and fill in your values.
/// app_secrets.dart is gitignored and never committed.
///
///   cp lib/core/constants/app_secrets_example.dart lib/core/constants/app_secrets.dart
///
/// Debug builds use dev values; release builds use prod values.
library;

// === Dev (debug builds) ===
const String auth0DomainDev = '';
const String auth0ClientIdDev = '';
const String convexDeploymentUrlDev = '';
const String telemetryEndpointUrlDev = '';

// === Prod (release builds) ===
const String auth0DomainProd = '';
const String auth0ClientIdProd = '';
const String convexDeploymentUrlProd = '';
const String telemetryEndpointUrlProd = '';

// === Shared ===
/// Custom scheme for Android redirect. Must match android/secrets.properties auth0Scheme.
const String auth0Scheme = 'com.shenepoy.hisab';
const String reportIssueUrl = 'https://github.com/Zyzto/Hisab/issues/new';
