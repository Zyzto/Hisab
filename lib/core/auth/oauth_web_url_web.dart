import 'package:web/web.dart' as web;

import '../navigation/decorative_route_web.dart' show safeHistoryReplaceUrl;

const _authParameters = {
  'code',
  'state',
  'access_token',
  'expires_in',
  'expires_at',
  'refresh_token',
  'token_type',
  'provider_token',
  'provider_refresh_token',
  'error',
  'error_code',
  'error_description',
  'type',
};

/// Current browser URL — same source supabase_flutter/app_links uses on web.
Uri? currentWebLocationUri() => Uri.parse(web.window.location.href);

/// Removes OAuth callback query/hash params from the URL without reloading.
///
/// After PKCE exchange (or a failed attempt), leaving `?code=` in the address
/// bar can re-trigger recovery on refresh and confuse mobile browsers.
///
/// Important: do not use [Uri.replace] with `queryParameters: null` to clear
/// the query — Dart keeps the old query in that case.
void clearWebAuthCallbackParams() {
  final current = Uri.parse(web.window.location.href);
  final query = Map<String, List<String>>.of(current.queryParametersAll)
    ..removeWhere((key, _) => _authParameters.contains(key));

  final cleaned = Uri(
    scheme: current.scheme,
    userInfo: current.userInfo,
    host: current.host,
    port: current.hasPort ? current.port : null,
    path: current.path.isEmpty ? '/' : current.path,
    queryParameters: query.isEmpty ? null : query,
    fragment: _cleanedFragment(current.fragment),
  );

  // Never pass null history state — it breaks Flutter/GoRouter web routing
  // so later context.go/push stop updating the address bar.
  safeHistoryReplaceUrl(cleaned.toString());
}

String? _cleanedFragment(String fragment) {
  if (fragment.isEmpty) return null;

  final fragmentParameters = Uri(query: fragment).queryParametersAll;
  final cleaned = {
    for (final entry in fragmentParameters.entries)
      if (!_authParameters.contains(entry.key)) entry.key: entry.value,
  };
  if (cleaned.length == fragmentParameters.length) return fragment;
  return cleaned.isEmpty ? null : Uri(queryParameters: cleaned).query;
}
