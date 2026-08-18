import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:hisab_backend/hisab_backend.dart';

import '../auth_service.dart';
import '../predefined_avatars.dart';
import '../sign_in_result.dart';
import 'auth_error_messages.dart';
import 'sign_in_state.dart';

/// How long a native OAuth or magic-link round trip may take before we give up
/// waiting for the deep link and let the user retry.
const Duration kAuthCallbackTimeout = Duration(minutes: 3);

/// Owns every async action and all mutable state behind the sign-in sheet.
///
/// Lives outside the widget so the flow can be exercised without pumping a
/// frame: the whole state machine is reachable from a plain unit test with a
/// fake [AuthService].
class SignInController extends ChangeNotifier {
  SignInController({
    required AuthService authService,
    bool? isWeb,
    Duration callbackTimeout = kAuthCallbackTimeout,
  }) : _auth = authService,
       _isWeb = isWeb ?? kIsWeb,
       _callbackTimeout = callbackTimeout;

  final AuthService _auth;

  /// On web an OAuth launch navigates the whole page away, so there is no
  /// callback to await — the sheet reports `pendingRedirect` and the session
  /// is picked up after the reload.
  final bool _isWeb;

  final Duration _callbackTimeout;

  SignInFormState _state = const SignInFormState();
  SignInFormState get state => _state;

  bool _disposed = false;

  void _emit(SignInFormState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Synchronous form interactions
  // ---------------------------------------------------------------------------

  /// Flips between sign-in and sign-up, always landing on the first step.
  void toggleMode() {
    if (_state.busy) return;
    _emit(
      _state.copyWith(
        mode: _state.isSignUp ? SignInMode.signIn : SignInMode.signUp,
        signUpStep: SignUpStep.credentials,
        selectedAvatarId: defaultAvatarId,
        clearError: true,
      ),
    );
  }

  void toggleObscurePassword() {
    _emit(_state.copyWith(obscurePassword: !_state.obscurePassword));
  }

  void selectAvatar(String avatarId) {
    if (_state.busy) return;
    _emit(_state.copyWith(selectedAvatarId: avatarId));
  }

  /// Advances sign-up to the name/avatar step. The caller validates the
  /// credentials form first.
  void goToProfileStep() {
    if (!_state.isSignUp || _state.busy) return;
    _emit(_state.copyWith(signUpStep: SignUpStep.profile, clearError: true));
  }

  void backToCredentials() {
    if (_state.busy) return;
    _emit(
      _state.copyWith(signUpStep: SignUpStep.credentials, clearError: true),
    );
  }

  void clearError() {
    if (_state.errorKey == null) return;
    _emit(_state.copyWith(clearError: true));
  }

  /// Requests the sheet close with [SignInResult.pendingEmailLink], used by the
  /// Done button on the "check your email" panels.
  void acknowledgePendingEmail() {
    _emit(
      _state.copyWith(
        emailLinkPending: true,
        outcome: SignInResult.pendingEmailLink,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Email / password
  // ---------------------------------------------------------------------------

  /// Signs in, or completes sign-up when [SignInFormState.mode] is sign-up.
  ///
  /// [name] is only read in sign-up mode and an empty value is sent as null so
  /// the backend falls back to deriving a display name from the address.
  Future<void> submit({
    required String email,
    required String password,
    String name = '',
  }) async {
    _emit(_state.copyWith(busy: true, clearError: true));
    try {
      if (_state.isSignUp) {
        final trimmedName = name.trim();
        final response = await _auth.signUpWithEmail(
          email,
          password,
          name: trimmedName.isEmpty ? null : trimmedName,
          avatarId: _state.selectedAvatarId,
        );
        // No session means the project requires email confirmation.
        if (response.session == null) {
          Log.info('Sign-up succeeded — email confirmation required');
          _emit(
            _state.copyWith(
              busy: false,
              panel: SignInPanel.awaitingConfirmation,
              confirmationResent: false,
              emailLinkPending: true,
              clearError: true,
            ),
          );
          return;
        }
        Log.info('User signed up with email');
      } else {
        await _auth.signInWithEmail(email, password);
        Log.info('User signed in with email');
      }
      _finish(SignInResult.success);
    } catch (e) {
      Log.warning('Email auth failed', error: e);
      _failEmailAuth(e);
    }
  }

  void _failEmailAuth(Object error) {
    if (isEmailNotConfirmedError(error)) {
      // Not a dead end: the account exists and a link is already in the inbox.
      _emit(
        _state.copyWith(
          busy: false,
          panel: SignInPanel.awaitingConfirmation,
          confirmationResent: false,
          emailLinkPending: true,
          clearError: true,
        ),
      );
      return;
    }
    _emit(_state.copyWith(busy: false, errorKey: authErrorKey(error)));
  }

  /// Re-sends the confirmation email for an account that was never verified.
  Future<void> resendConfirmation(String email) async {
    if (email.trim().isEmpty) return;
    _emit(_state.copyWith(busy: true, clearError: true));
    try {
      await _auth.resendConfirmation(email.trim());
      _emit(
        _state.copyWith(busy: false, confirmationResent: true, clearError: true),
      );
    } catch (e) {
      Log.warning('Resend confirmation failed', error: e);
      if (isRateLimitError(e)) {
        // Being throttled means an email went out recently, which is what the
        // user wanted. Showing an error here would be actively misleading.
        _emit(
          _state.copyWith(
            busy: false,
            confirmationResent: true,
            clearError: true,
          ),
        );
        return;
      }
      _emit(_state.copyWith(busy: false, errorKey: authErrorKey(e)));
    }
  }

  // ---------------------------------------------------------------------------
  // Passwordless
  // ---------------------------------------------------------------------------

  Future<void> sendMagicLink(String email) async {
    _emit(_state.copyWith(busy: true, clearError: true));

    Completer<bool>? completer;
    StreamSubscription<CloudAuthState>? sub;
    try {
      if (!_isWeb) {
        if (_auth.isAuthenticated) {
          _emit(_state.copyWith(busy: false, emailLinkPending: true));
          _finish(SignInResult.success);
          return;
        }
        // Subscribe before sending so a fast callback cannot be missed.
        completer = _listenForSignIn((s) => sub = s);
      }

      await _auth.signInWithMagicLink(email);

      _emit(
        _state.copyWith(
          panel: SignInPanel.magicLinkSent,
          emailLinkPending: true,
          // Web idles with a Done button; native keeps waiting for the deep link.
          busy: !_isWeb,
        ),
      );
      if (_isWeb) return;

      Log.debug('Waiting for magic-link callback (native)');
      await _awaitCallback(completer!, label: 'Magic-link');
    } catch (e) {
      Log.warning('Magic link failed', error: e);
      _emit(_state.copyWith(busy: false, errorKey: authErrorKey(e)));
    } finally {
      await sub?.cancel();
    }
  }

  /// Emails a password recovery link.
  ///
  /// Unlike magic link, this never waits for a callback even on native: the
  /// recovery link opens the set-a-new-password sheet from the app root, so the
  /// sign-in sheet's job ends the moment the email is away.
  Future<void> sendPasswordReset(String email) async {
    _emit(_state.copyWith(busy: true, clearError: true));
    try {
      await _auth.requestPasswordReset(email);
      _emit(
        _state.copyWith(
          busy: false,
          panel: SignInPanel.resetSent,
          emailLinkPending: true,
          clearError: true,
        ),
      );
    } catch (e) {
      Log.warning('Password reset request failed', error: e);
      _emit(_state.copyWith(busy: false, errorKey: authErrorKey(e)));
    }
  }

  // ---------------------------------------------------------------------------
  // OAuth
  // ---------------------------------------------------------------------------

  Future<void> signInWithProvider(CloudOAuthProvider provider) async {
    _emit(_state.copyWith(busy: true, clearError: true));
    if (provider == CloudOAuthProvider.google && !_isWeb) {
      if (await _tryNativeGoogle()) return;
    }
    await _launchOAuthInBrowser(provider);
  }

  /// Attempts the in-app Google account picker.
  ///
  /// Returns whether it settled the attempt. A configuration problem (a missing
  /// SHA-1, say) falls back to the browser rather than blocking sign-in, since
  /// the browser flow reaches the same Supabase provider.
  Future<bool> _tryNativeGoogle() async {
    try {
      switch (await _auth.signInWithNativeGoogle()) {
        case NativeGoogleOutcome.signedIn:
          Log.info('Google sign-in completed in-app');
          _finish(SignInResult.success);
          return true;
        case NativeGoogleOutcome.cancelled:
          // Backing out of the account picker is a decision, not a failure.
          _emit(_state.copyWith(busy: false));
          return true;
        case NativeGoogleOutcome.unsupported:
          return false;
      }
    } catch (e) {
      Log.warning(
        'Native Google sign-in failed; falling back to the browser',
        error: e,
      );
      return false;
    }
  }

  Future<void> _launchOAuthInBrowser(CloudOAuthProvider provider) async {
    final label = provider == CloudOAuthProvider.google ? 'Google' : 'GitHub';
    Completer<bool>? completer;
    StreamSubscription<CloudAuthState>? sub;
    try {
      // Subscribe before launch on native so a fast callback cannot be missed.
      if (!_isWeb) completer = _listenForSignIn((s) => sub = s);

      final launched = provider == CloudOAuthProvider.google
          ? await _auth.signInWithGoogle()
          : await _auth.signInWithGithub();

      if (!launched) {
        _emit(
          _state.copyWith(busy: false, errorKey: AuthErrorKeys.oauthFailed),
        );
        return;
      }

      if (_isWeb) {
        Log.info('$label OAuth redirect started (web)');
        _finish(SignInResult.pendingRedirect);
        return;
      }

      Log.debug('Waiting for $label OAuth callback (native)');
      await _awaitCallback(completer!, label: '$label OAuth');
    } catch (e) {
      Log.warning('OAuth sign-in failed', error: e);
      _emit(_state.copyWith(busy: false, errorKey: authErrorKey(e)));
    } finally {
      await sub?.cancel();
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Completer<bool> _listenForSignIn(
    void Function(StreamSubscription<CloudAuthState>) keep,
  ) {
    final completer = Completer<bool>();
    keep(
      _auth.onAuthStateChange.listen((s) {
        if (s.event == CloudAuthEvent.signedIn && !completer.isCompleted) {
          completer.complete(true);
        }
      }),
    );
    return completer;
  }

  Future<void> _awaitCallback(
    Completer<bool> completer, {
    required String label,
  }) async {
    final ok = await completer.future.timeout(
      _callbackTimeout,
      onTimeout: () => false,
    );
    if (ok) {
      Log.info('$label sign-in completed (native)');
      _finish(SignInResult.success);
    } else {
      Log.warning('$label timed out');
      _emit(_state.copyWith(busy: false, errorKey: AuthErrorKeys.oauthTimeout));
    }
  }

  void _finish(SignInResult result) {
    _emit(_state.copyWith(busy: false, outcome: result));
  }
}
