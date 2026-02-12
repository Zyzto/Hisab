import 'package:auth0_flutter/auth0_flutter.dart';

import '../constants/auth_config.dart';
import '../constants/convex_config.dart';

// Conditional imports for web vs native
import 'auth_service_impl_native.dart'
    if (dart.library.html) 'auth_service_impl_web.dart' as impl;

/// Whether Auth0 is configured and online mode can be used.
bool get auth0ConfigAvailable =>
    auth0Domain.isNotEmpty &&
    auth0ClientId.isNotEmpty &&
    convexDeploymentUrl.isNotEmpty;

/// Sign in with Auth0. Returns access token or null.
Future<String?> auth0SignIn() => impl.auth0SignIn();

/// Sign out from Auth0.
Future<void> auth0SignOut() => impl.auth0SignOut();

/// Get current access token for Convex. Returns null if not signed in.
Future<String?> auth0GetAccessToken() => impl.auth0GetAccessToken();

/// Check if user has valid credentials.
Future<bool> auth0HasValidCredentials() => impl.auth0HasValidCredentials();

/// (Web only) Process Auth0 redirect callback. Call on app load to restore session.
/// Returns credentials if coming back from redirect, null otherwise.
Future<Credentials?> auth0OnLoad() => impl.auth0OnLoad();
