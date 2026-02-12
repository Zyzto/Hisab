import 'package:auth0_flutter/auth0_flutter.dart' show Auth0, Credentials;
import 'package:flutter_logging_service/flutter_logging_service.dart';

import '../constants/auth_config.dart';

Future<String?> auth0SignIn() async {
  if (auth0Domain.isEmpty || auth0ClientId.isEmpty) return null;
  try {
    final auth0 = Auth0(auth0Domain, auth0ClientId);
    final redirectUrl = auth0Scheme.isNotEmpty
        ? '$auth0Scheme://$auth0Domain/android/$auth0Scheme/callback'
        : null;
    final credentials = await auth0.webAuthentication(
      scheme: auth0Scheme.isNotEmpty ? auth0Scheme : null,
    ).login(redirectUrl: redirectUrl);
    Log.info('User signed in');
    return credentials.accessToken;
  } catch (e, st) {
    Log.warning('Auth0 sign-in failed', error: e, stackTrace: st);
    return null;
  }
}

Future<void> auth0SignOut() async {
  if (auth0Domain.isEmpty || auth0ClientId.isEmpty) return;
  try {
    final auth0 = Auth0(auth0Domain, auth0ClientId);
    final returnTo = auth0Scheme.isNotEmpty
        ? '$auth0Scheme://$auth0Domain/android/$auth0Scheme/callback'
        : null;
    await auth0.webAuthentication(
      scheme: auth0Scheme.isNotEmpty ? auth0Scheme : null,
    ).logout(returnTo: returnTo);
    Log.info('User signed out');
  } catch (e, st) {
    Log.warning('Auth0 sign-out failed', error: e, stackTrace: st);
  }
}

Future<String?> auth0GetAccessToken() async {
  if (auth0Domain.isEmpty || auth0ClientId.isEmpty) return null;
  try {
    final auth0 = Auth0(auth0Domain, auth0ClientId);
    final credentials = await auth0.credentialsManager.credentials();
    // Convex Auth0 expects the ID token for authenticated requests (not access token).
    return credentials.idToken ?? credentials.accessToken;
  } catch (e) {
    Log.debug('Auth0 getAccessToken failed: $e');
    return null;
  }
}

Future<bool> auth0HasValidCredentials() async {
  if (auth0Domain.isEmpty || auth0ClientId.isEmpty) return false;
  try {
    final auth0 = Auth0(auth0Domain, auth0ClientId);
    return await auth0.credentialsManager.hasValidCredentials();
  } catch (_) {
    return false;
  }
}

/// No-op on native; redirect handling is web-only.
Future<Credentials?> auth0OnLoad() async => null;
