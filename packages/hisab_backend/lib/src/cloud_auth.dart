import 'models.dart';

/// Authentication and identity.
///
/// Every method throws [CloudException] on failure. Getters must never throw:
/// they return null when there is no session.
abstract interface class CloudAuth {
  /// The signed-in user, or null.
  CloudUser? get currentUser;

  /// The active session, or null.
  CloudSession? get currentSession;

  bool get isAuthenticated;

  /// Emits on every session change. Must emit a
  /// [CloudAuthEvent.initialSession] event once on subscribe so late listeners
  /// converge on the current state.
  Stream<CloudAuthState> get authStateChanges;

  Future<CloudAuthResponse> signInWithEmail(String email, String password);

  /// Creates an account. When the backend requires email confirmation, the
  /// returned response carries a user but no session.
  Future<CloudAuthResponse> signUpWithEmail(
    String email,
    String password, {
    String? name,
    String? avatarId,
  });

  /// Sends a one-time sign-in link to [email].
  Future<void> signInWithMagicLink(String email);

  /// Starts an OAuth flow. Returns whether the flow was launched, not whether
  /// it succeeded — completion arrives on [authStateChanges].
  Future<bool> signInWithOAuth(CloudOAuthProvider provider);

  Future<void> signOut();

  /// Merges [name] and [avatarId] into the current user's metadata. A no-op
  /// when signed out.
  Future<void> updateProfile({String? name, String? avatarId});

  /// The caller is responsible for re-verifying identity first.
  Future<void> updatePassword(String newPassword);

  Future<void> resendConfirmation(String email);

  /// Forces a token refresh. Used before a bulk upload so a long migration
  /// does not fail halfway on an expired token.
  Future<void> refreshSession();

  /// Finishes an OAuth or magic-link redirect that landed back on the web app,
  /// consuming any code or fragment in the current URL. A no-op off the web and
  /// when there is nothing to complete. Must not throw.
  Future<void> completeWebRedirect();
}
