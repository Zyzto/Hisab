/// Supabase configuration.
///
/// Values are provided via `--dart-define` at build time.
/// When empty, the app runs fully offline with no online features.
///
/// Example:
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
library;

import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

/// Whether Supabase is configured and online mode can be used.
bool get supabaseConfigAvailable =>
    supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

/// Returns the Supabase client only when Supabase is configured (and thus
/// initialized in main). Returns null in local-only mode or when config is
/// missing, so callers avoid throwing when Supabase is not used.
SupabaseClient? get supabaseClientIfConfigured {
  if (!supabaseConfigAvailable) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

/// Optional custom base URL for invite links (e.g. custom domain).
/// When set via `--dart-define=INVITE_BASE_URL=https://invite.example.com`,
/// generated invite links use this instead of [supabaseUrl].
/// Use this with Supabase Custom Domain so links show your brand (no extra hosting).
const inviteBaseUrl = String.fromEnvironment('INVITE_BASE_URL', defaultValue: '');

/// Base URL used to build invite redirect links. Prefers [inviteBaseUrl] when set.
String get inviteLinkBaseUrl =>
    inviteBaseUrl.trim().isNotEmpty ? inviteBaseUrl.trim() : supabaseUrl;

/// Optional redirect URL for auth emails (magic link, sign-up confirmation, resend).
/// When set via `--dart-define=SITE_URL=https://yourdomain.com`, email verification
/// and magic links will redirect here instead of the Supabase default (e.g. localhost).
/// Must be listed in Supabase Dashboard → Authentication → URL Configuration → Redirect URLs.
const authRedirectUrl = String.fromEnvironment('SITE_URL', defaultValue: '');

/// Deep link used for OAuth redirect on native (Android/iOS) so the app reopens after sign-in.
/// Must be listed in Supabase Dashboard → Authentication → URL Configuration → Redirect URLs.
const authOAuthCallbackDeepLink = 'io.supabase.hisab://callback';

/// VAPID key for Firebase Cloud Messaging on web.
/// Generated in Firebase Console → Project Settings → Cloud Messaging → Web Push certificates.
/// Required for `FirebaseMessaging.instance.getToken(vapidKey: ...)` on web.
const fcmVapidKey = String.fromEnvironment('FCM_VAPID_KEY', defaultValue: '');

/// Set to true after `Firebase.initializeApp()` succeeds in main.dart.
/// Guards all Firebase-dependent code (notifications) at runtime.
bool firebaseInitialized = false;
