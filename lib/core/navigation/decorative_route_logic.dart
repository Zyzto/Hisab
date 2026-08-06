import 'package:flutter/foundation.dart';

/// App-route pathnames that must never sit in `window.location.pathname`
/// while Hisab uses Flutter's default hash URL strategy.
const _leakedAppPathPrefixes = <String>[
  '/groups',
  '/settings',
  '/home',
  '/onboarding',
  '/invite',
  '/profile',
  '/privacy-policy',
  '/archived',
  '/scan-invite',
  '/functions',
];

/// Whether [pathname] looks like an in-app route leaked into the document path.
@visibleForTesting
bool isLeakedAppPathname(String pathname) {
  return _leakedAppPathPrefixes.any(
    (p) => pathname == p || pathname.startsWith('$p/'),
  );
}

/// Document pathname for hash URL strategy (usually `/`).
///
/// Used by web decorative-route helpers; also covered by unit tests.
String hashStrategyPathname(String pathname) {
  if (pathname.endsWith('.html')) return pathname;
  if (isLeakedAppPathname(pathname)) return '/';
  if (pathname.isEmpty) return '/';
  return pathname;
}

/// Extracts the in-app route path from a browser [Uri].
///
/// Flutter web defaults to **hash** URL strategy (`/#/groups/...`), where the
/// route lives in [Uri.fragment]. Path URL strategy stores it in [Uri.path].
/// OAuth callback hashes (`#access_token=...`) do not start with `/` and are
/// ignored so pathname is used instead.
String appRoutePathFromBrowserUri(Uri uri) {
  final fragment = uri.fragment;
  if (fragment.startsWith('/')) {
    final queryIndex = fragment.indexOf('?');
    return queryIndex == -1 ? fragment : fragment.substring(0, queryIndex);
  }
  return uri.path.isEmpty ? '/' : uri.path;
}
