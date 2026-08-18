import 'dart:async';

import 'package:hisab/core/auth/auth_service.dart';
import 'package:hisab_backend/hisab_backend.dart';

const CloudUser kTestUser = CloudUser(id: 'user-1', email: 'a@b.co');
const CloudSession kTestSession = CloudSession(user: kTestUser);

/// Scriptable stand-in for [AuthService].
///
/// Every method records its call and either throws the matching `*Error` or
/// returns the configured result, so a test can drive the sign-in controller
/// through any branch without a backend.
class FakeAuthService extends AuthService {
  final _authStates = StreamController<CloudAuthState>.broadcast();

  /// Method names in call order, e.g. `signInWithEmail`.
  final List<String> calls = <String>[];

  /// Arguments of the last email sign-up, for asserting name/avatar plumbing.
  ({String email, String password, String? name, String? avatarId})? lastSignUp;

  Object? signInError;
  Object? signUpError;
  Object? magicLinkError;
  Object? resendError;
  Object? oauthError;
  Object? resetError;

  /// Sign-up result. A null session means email confirmation is required.
  CloudAuthResponse signUpResponse = const CloudAuthResponse(
    user: kTestUser,
    session: kTestSession,
  );

  /// What `signInWithOAuth` reports about launching the browser.
  bool oauthLaunched = true;

  /// Default mirrors an offline or web build, where the browser flow is the
  /// only Google path.
  NativeGoogleOutcome nativeGoogleOutcome = NativeGoogleOutcome.unsupported;
  Object? nativeGoogleError;

  /// When true, a `signedIn` event follows an OAuth launch or a magic link,
  /// standing in for the deep link coming back into the app.
  bool emitSignedInAfterLaunch = false;

  bool authenticated = false;

  @override
  bool get isAuthenticated => authenticated;

  @override
  Stream<CloudAuthState> get onAuthStateChange => _authStates.stream;

  void emitSignedIn() {
    _authStates.add(const CloudAuthState(CloudAuthEvent.signedIn, kTestSession));
  }

  Future<void> close() => _authStates.close();

  void _maybeEmitSignedIn() {
    if (!emitSignedInAfterLaunch) return;
    scheduleMicrotask(emitSignedIn);
  }

  @override
  Future<CloudAuthResponse> signInWithEmail(String email, String password) async {
    calls.add('signInWithEmail');
    if (signInError != null) throw signInError!;
    return const CloudAuthResponse(user: kTestUser, session: kTestSession);
  }

  @override
  Future<CloudAuthResponse> signUpWithEmail(
    String email,
    String password, {
    String? name,
    String? avatarId,
  }) async {
    calls.add('signUpWithEmail');
    lastSignUp = (
      email: email,
      password: password,
      name: name,
      avatarId: avatarId,
    );
    if (signUpError != null) throw signUpError!;
    return signUpResponse;
  }

  @override
  Future<void> signInWithMagicLink(String email) async {
    calls.add('signInWithMagicLink');
    if (magicLinkError != null) throw magicLinkError!;
    _maybeEmitSignedIn();
  }

  Object? updatePasswordError;

  /// Last value handed to [updatePassword].
  String? lastNewPassword;

  @override
  Future<void> updatePassword(String newPassword) async {
    calls.add('updatePassword');
    lastNewPassword = newPassword;
    if (updatePasswordError != null) throw updatePasswordError!;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    calls.add('requestPasswordReset');
    if (resetError != null) throw resetError!;
  }

  @override
  Future<void> resendConfirmation(String email) async {
    calls.add('resendConfirmation');
    if (resendError != null) throw resendError!;
  }

  @override
  Future<NativeGoogleOutcome> signInWithNativeGoogle() async {
    calls.add('signInWithNativeGoogle');
    if (nativeGoogleError != null) throw nativeGoogleError!;
    return nativeGoogleOutcome;
  }

  @override
  Future<bool> signInWithGoogle() => _oauth('signInWithGoogle');

  @override
  Future<bool> signInWithGithub() => _oauth('signInWithGithub');

  Future<bool> _oauth(String name) async {
    calls.add(name);
    if (oauthError != null) throw oauthError!;
    if (oauthLaunched) _maybeEmitSignedIn();
    return oauthLaunched;
  }
}
