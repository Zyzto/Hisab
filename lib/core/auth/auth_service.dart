import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:hisab_backend/hisab_backend.dart';

import 'auth_user_profile.dart';

/// Thin delegate over the registered backend's [CloudAuth].
///
/// In an offline build no backend is registered, so the getters return
/// null/false and every action throws [StateError] rather than being called at
/// all — the UI hides these affordances behind `cloudAvailable`.
class AuthService {
  CloudAuth? get _auth => cloudBackend?.auth;

  CloudAuth get _authOrThrow =>
      cloudBackend?.auth ?? (throw StateError('No cloud backend configured'));

  // ---------------------------------------------------------------------------
  // Sign-in methods
  // ---------------------------------------------------------------------------

  Future<CloudAuthResponse> signInWithEmail(
    String email,
    String password,
  ) async {
    Log.debug('Signing in with email');
    try {
      final response = await _authOrThrow.signInWithEmail(email, password);
      Log.info('User signed in with email');
      return response;
    } catch (e, st) {
      Log.error('Email sign-in failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<CloudAuthResponse> signUpWithEmail(
    String email,
    String password, {
    String? name,
    String? avatarId,
  }) async {
    Log.debug('Signing up with email');
    try {
      final response = await _authOrThrow.signUpWithEmail(
        email,
        password,
        name: name,
        avatarId: avatarId,
      );
      Log.info('User signed up with email');
      return response;
    } catch (e, st) {
      Log.error('Email sign-up failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Update the current user's name and/or avatar.
  Future<void> updateProfile({String? name, String? avatarId}) async {
    if (currentUser == null) return;
    await _authOrThrow.updateProfile(name: name, avatarId: avatarId);
    Log.info('Profile updated');
  }

  /// Update the current user's password. Caller must verify identity (e.g. via
  /// [signInWithEmail] with the current password) before calling.
  Future<void> updatePassword(String newPassword) async {
    Log.debug('Updating password');
    try {
      await _authOrThrow.updatePassword(newPassword);
      Log.info('Password updated');
    } catch (e, st) {
      Log.error('Password update failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Resend the confirmation email for an unconfirmed account.
  Future<void> resendConfirmation(String email) async {
    Log.debug('Resending confirmation email');
    try {
      await _authOrThrow.resendConfirmation(email);
      Log.info('Confirmation email resent');
    } catch (e, st) {
      Log.error('Resend confirmation failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> signInWithMagicLink(String email) async {
    Log.debug('Sending magic link');
    try {
      await _authOrThrow.signInWithMagicLink(email);
      Log.info('Magic link sent');
    } catch (e, st) {
      Log.error('Magic link failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() =>
      _signInWithOAuth(CloudOAuthProvider.google);

  Future<bool> signInWithGithub() =>
      _signInWithOAuth(CloudOAuthProvider.github);

  Future<bool> _signInWithOAuth(CloudOAuthProvider provider) async {
    Log.debug('Signing in with ${provider.name} OAuth');
    try {
      return await _authOrThrow.signInWithOAuth(provider);
    } catch (e, st) {
      Log.error('${provider.name} sign-in failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign-out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    Log.info('User signing out');
    try {
      await _authOrThrow.signOut();
      Log.info('User signed out');
    } catch (e, st) {
      Log.error('Sign-out failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Session & user getters (safe offline — return null/false/empty)
  // ---------------------------------------------------------------------------

  CloudSession? get currentSession => _auth?.currentSession;

  CloudUser? get currentUser => _auth?.currentUser;

  bool get isAuthenticated => _auth?.isAuthenticated ?? false;

  Stream<CloudAuthState> get onAuthStateChange =>
      _auth?.authStateChanges ?? const Stream.empty();

  // ---------------------------------------------------------------------------
  // Profile helper
  // ---------------------------------------------------------------------------

  AuthUserProfile? getUserProfile() {
    final user = currentUser;
    if (user == null) return null;
    return AuthUserProfile(
      name: user.fullName,
      email: user.email,
      sub: user.id,
      avatarId: user.avatarId,
    );
  }
}
