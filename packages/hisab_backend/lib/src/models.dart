/// Neutral data models shared between the Hisab app and any cloud backend.
///
/// These deliberately avoid any vendor type so the app never links a specific
/// backend SDK.
library;

/// An authenticated user.
class CloudUser {
  const CloudUser({
    required this.id,
    this.email,
    this.provider,
    this.metadata = const <String, dynamic>{},
  });

  /// Stable backend user id. Used as `user_id` on every synced row.
  final String id;

  final String? email;

  /// Identity provider that issued the session, lowercase: `email`, `google`,
  /// `github`, … Hisab only offers a password change when this is `email`.
  final String? provider;

  /// Free-form profile data. Hisab reads `full_name`, `name` and `avatar_id`.
  final Map<String, dynamic> metadata;

  /// Display name, preferring `full_name` over `name`.
  String? get fullName =>
      metadata['full_name'] as String? ?? metadata['name'] as String?;

  String? get avatarId => metadata['avatar_id'] as String?;

  CloudUser copyWith({
    String? id,
    String? email,
    String? provider,
    Map<String, dynamic>? metadata,
  }) => CloudUser(
    id: id ?? this.id,
    email: email ?? this.email,
    provider: provider ?? this.provider,
    metadata: metadata ?? this.metadata,
  );

  @override
  String toString() => 'CloudUser(id: $id, email: $email)';
}

/// An active session. Hisab only needs to know that one exists and who it is
/// for; the access token is exposed for backends that need it downstream.
class CloudSession {
  const CloudSession({
    required this.user,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final CloudUser user;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
}

/// Why [CloudAuthState] was emitted.
enum CloudAuthEvent {
  initialSession,
  signedIn,
  signedOut,
  tokenRefreshed,
  userUpdated,
  passwordRecovery,
  other,
}

/// A single emission on [CloudAuth.authStateChanges].
class CloudAuthState {
  const CloudAuthState(this.event, this.session);

  final CloudAuthEvent event;

  /// Null when signed out.
  final CloudSession? session;

  CloudUser? get user => session?.user;
}

/// Result of an email sign-in or sign-up.
///
/// Both fields may be null: sign-up with email confirmation enabled returns a
/// user with no session until the link is followed.
class CloudAuthResponse {
  const CloudAuthResponse({this.user, this.session});

  final CloudUser? user;
  final CloudSession? session;
}

/// OAuth providers Hisab offers.
enum CloudOAuthProvider { google, github }

/// Broad category of a [CloudException], so the app can decide whether to
/// retry, re-authenticate, or surface the error, without parsing messages.
enum CloudErrorKind {
  /// Not signed in, token expired, or forbidden. Never retry.
  auth,

  /// Connectivity failure or timeout. Safe to retry with backoff.
  network,

  /// Backend rejected the request as malformed or disallowed by policy.
  /// Retrying unchanged will not help.
  invalidRequest,

  /// The requested row does not exist or is not visible to this user.
  notFound,

  /// Backend fault (5xx) or rate limit. Safe to retry with backoff.
  server,

  unknown,
}

/// The single exception type a backend may throw across the contract.
///
/// Implementations must translate vendor errors into this type so the app's
/// retry and sign-out logic stays backend agnostic.
class CloudException implements Exception {
  const CloudException(
    this.message, {
    this.kind = CloudErrorKind.unknown,
    this.statusCode,
    this.code,
    this.cause,
  });

  final String message;
  final CloudErrorKind kind;

  /// HTTP status when the failure came from an HTTP call.
  final int? statusCode;

  /// Backend-specific error code, for diagnostics only. The app must not
  /// branch on this.
  final String? code;

  /// The original error, kept for logging.
  final Object? cause;

  bool get isAuthError =>
      kind == CloudErrorKind.auth || statusCode == 401 || statusCode == 403;

  bool get isTransient =>
      kind == CloudErrorKind.network ||
      kind == CloudErrorKind.server ||
      (statusCode != null && (statusCode! >= 500 || statusCode == 429));

  @override
  String toString() =>
      'CloudException(${kind.name}${statusCode == null ? '' : ' $statusCode'}): $message';
}

/// Outcome of [CloudHealth.probe].
enum CloudHealthStatus {
  /// Backend answered successfully.
  active,

  /// Backend exists but is suspended or sleeping (for example a free-tier
  /// project paused for inactivity). Usually recoverable by the operator.
  paused,

  /// Could not be reached, or answered unexpectedly.
  unreachable,

  /// This build has no backend configured.
  notConfigured,
}

/// A health probe result with an optional diagnostic message.
class CloudHealthResult {
  const CloudHealthResult(this.status, [this.message]);

  final CloudHealthStatus status;
  final String? message;

  @override
  String toString() =>
      'CloudHealthResult(${status.name}${message == null ? '' : ': $message'})';
}
