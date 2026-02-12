import 'package:auth0_flutter/auth0_flutter.dart' show Credentials;
import 'package:auth0_flutter/auth0_flutter_web.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';

import '../constants/auth_config.dart';

Future<String?> auth0SignIn() async {
  if (auth0Domain.isEmpty || auth0ClientId.isEmpty) return null;
  try {
    final auth0Web = Auth0Web(auth0Domain, auth0ClientId);
    await auth0Web.loginWithRedirect(
      redirectUrl: Uri.base.origin,
    );
    return null;
  } catch (e, st) {
    Log.warning('Auth0 sign-in failed', error: e, stackTrace: st);
    return null;
  }
}

Future<Credentials?> auth0OnLoad() async {
  if (auth0Domain.isEmpty || auth0ClientId.isEmpty) return null;
  try {
    final auth0Web = Auth0Web(auth0Domain, auth0ClientId);
    return await auth0Web.onLoad();
  } catch (e) {
    Log.debug('Auth0 onLoad: $e');
    return null;
  }
}

Future<void> auth0SignOut() async {
  if (auth0Domain.isEmpty || auth0ClientId.isEmpty) return;
  try {
    final auth0Web = Auth0Web(auth0Domain, auth0ClientId);
    await auth0Web.logout(returnToUrl: Uri.base.origin);
    Log.info('User signed out');
  } catch (e, st) {
    Log.warning('Auth0 sign-out failed', error: e, stackTrace: st);
  }
}

Future<String?> auth0GetAccessToken() async {
  if (auth0Domain.isEmpty || auth0ClientId.isEmpty) return null;
  try {
    final auth0Web = Auth0Web(auth0Domain, auth0ClientId);
    final credentials = await auth0Web.credentials();
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
    final auth0Web = Auth0Web(auth0Domain, auth0ClientId);
    return await auth0Web.hasValidCredentials();
  } catch (_) {
    return false;
  }
}
