import 'package:hisab_backend/hisab_backend.dart';

/// Translation keys this module can return.
///
/// Kept as constants so the controller and its tests agree on the exact key
/// without either of them needing a localization delegate.
abstract final class AuthErrorKeys {
  static const String generic = 'auth_generic_error';
  static const String invalidCredentials = 'auth_invalid_credentials';
  static const String alreadyRegistered = 'auth_already_registered';
  static const String emailNotConfirmed = 'auth_email_not_confirmed';
  static const String rateLimit = 'auth_rate_limit';
  static const String passwordTooShort = 'auth_password_too_short';
  static const String oauthFailed = 'auth_oauth_failed';
  static const String oauthTimeout = 'auth_oauth_timeout';
}

/// Whether [error] means "the account exists but the address is unverified".
///
/// This is the one failure the UI treats as progress rather than a dead end:
/// it offers to resend the confirmation instead of showing a red banner.
bool isEmailNotConfirmedError(Object error) {
  if (error is CloudException) {
    if (error.code == 'email_not_confirmed') return true;
    return error.message.toLowerCase().contains('email not confirmed');
  }
  final text = error.toString();
  return text.contains('email_not_confirmed') ||
      text.contains('Email not confirmed');
}

/// Whether [error] is the backend throttling us rather than rejecting input.
bool isRateLimitError(Object error) {
  if (error is CloudException && error.code == 'over_email_send_rate_limit') {
    return true;
  }
  final text = error.toString().toLowerCase();
  return text.contains('rate limit') || text.contains('rate_limit');
}

/// Maps an auth failure to a translation key.
///
/// Returns a key rather than a translated string so this stays a pure function
/// callable from unit tests. Callers translate it, passing `min` for the
/// password-length case; easy_localization ignores unused named args.
String authErrorKey(Object error) {
  if (isEmailNotConfirmedError(error)) return AuthErrorKeys.emailNotConfirmed;
  if (isRateLimitError(error)) return AuthErrorKeys.rateLimit;

  if (error is CloudException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return AuthErrorKeys.invalidCredentials;
    }
    if (message.contains('already registered') ||
        error.code == 'user_already_exists') {
      return AuthErrorKeys.alreadyRegistered;
    }
    if (_looksLikeWeakPassword(message)) return AuthErrorKeys.passwordTooShort;
    return AuthErrorKeys.generic;
  }

  final text = error.toString();
  if (text.contains('Invalid login credentials')) {
    return AuthErrorKeys.invalidCredentials;
  }
  if (text.contains('User already registered')) {
    return AuthErrorKeys.alreadyRegistered;
  }
  if (_looksLikeWeakPassword(text.toLowerCase())) {
    return AuthErrorKeys.passwordTooShort;
  }
  return AuthErrorKeys.generic;
}

bool _looksLikeWeakPassword(String lowercaseText) {
  return lowercaseText.contains('password should be at least') ||
      lowercaseText.contains('weak_password');
}
