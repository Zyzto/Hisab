import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_config.dart';
import 'auth_user_profile.dart';

/// Unified Supabase auth service. Works on all platforms — `supabase_flutter`
/// handles web/native differences internally.
class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Sign-in methods
  // ---------------------------------------------------------------------------

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    Log.debug('Signing in with email');
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      Log.info('User signed in with email');
      return response;
    } catch (e, st) {
      Log.error('Email sign-in failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmail(
    String email,
    String password, {
    String? name,
    String? avatarId,
  }) async {
    Log.debug('Signing up with email');
    try {
      final data = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) {
        data['full_name'] = name.trim();
      }
      if (avatarId != null && avatarId.isNotEmpty) {
        data['avatar_id'] = avatarId;
      }
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: authRedirectUrl.trim().isNotEmpty
            ? authRedirectUrl.trim()
            : null,
        data: data.isNotEmpty ? data : null,
      );
      Log.info('User signed up with email');
      return response;
    } catch (e, st) {
      Log.error('Email sign-up failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Update the current user's profile (name and/or avatar). Persists to Supabase user_metadata.
  Future<void> updateProfile({String? name, String? avatarId}) async {
    final user = currentUser;
    if (user == null) return;
    final existing = Map<String, dynamic>.from(user.userMetadata ?? {});
    if (name != null) {
      existing['full_name'] = name.trim().isEmpty ? null : name.trim();
    }
    if (avatarId != null) {
      existing['avatar_id'] = avatarId.isEmpty ? null : avatarId;
    }
    await _client.auth.updateUser(UserAttributes(data: existing));
    Log.info('Profile updated');
  }

  /// Resend the confirmation email for an unconfirmed account.
  Future<void> resendConfirmation(String email) async {
    Log.debug('Resending confirmation email');
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: authRedirectUrl.trim().isNotEmpty
            ? authRedirectUrl.trim()
            : null,
      );
      Log.info('Confirmation email resent');
    } catch (e, st) {
      Log.error('Resend confirmation failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> signInWithMagicLink(String email) async {
    Log.debug('Sending magic link');
    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: authRedirectUrl.trim().isNotEmpty
            ? authRedirectUrl.trim()
            : null,
      );
      Log.info('Magic link sent');
    } catch (e, st) {
      Log.error('Magic link failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() async {
    Log.debug('Signing in with Google OAuth');
    try {
      final ok = await _client.auth.signInWithOAuth(OAuthProvider.google);
      return ok;
    } catch (e, st) {
      Log.error('Google sign-in failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<bool> signInWithGithub() async {
    Log.debug('Signing in with GitHub OAuth');
    try {
      final ok = await _client.auth.signInWithOAuth(OAuthProvider.github);
      return ok;
    } catch (e, st) {
      Log.error('GitHub sign-in failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign-out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    Log.info('User signing out');
    try {
      await _client.auth.signOut();
      Log.info('User signed out');
    } catch (e, st) {
      Log.error('Sign-out failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Session & user getters
  // ---------------------------------------------------------------------------

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  bool get isAuthenticated => _client.auth.currentSession != null;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  // ---------------------------------------------------------------------------
  // Profile helper (mirrors old AuthUserProfile)
  // ---------------------------------------------------------------------------

  AuthUserProfile? getUserProfile() {
    final user = currentUser;
    if (user == null) return null;
    return AuthUserProfile(
      name:
          user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String?,
      email: user.email,
      sub: user.id,
      avatarId: user.userMetadata?['avatar_id'] as String?,
    );
  }
}

/// Whether Supabase is configured and online mode can be used.
bool get supabaseOnlineAvailable => supabaseConfigAvailable;
