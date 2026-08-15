/// Deep link the app registers for OAuth and magic-link callbacks.
///
/// A backend must accept this exact value in its redirect allowlist, otherwise
/// native sign-in strands the user in a browser holding a PKCE verifier the app
/// can no longer reach.
const String hisabAuthCallbackDeepLink = 'com.shenepoy.hisab://callback';

/// Deep link accepted for installs predating the scheme rename. Backends should
/// allowlist it alongside [hisabAuthCallbackDeepLink] until those installs age
/// out.
const String legacyHisabAuthCallbackDeepLink = 'io.supabase.hisab://callback';

/// Where a backend should send the user after OAuth or an emailed auth link.
///
/// - Native: [nativeDeepLink], so the PKCE verifier stays inside the app.
/// - Web: [configuredSiteUrl], upgraded from http to https when the page is
///   already served over https on the same host. Without that upgrade a host
///   that redirects http to https turns the callback into a 301 and drops the
///   auth fragment.
/// - Web with no configured site URL: null, letting the backend fall back to
///   its own default site URL.
String? resolveAuthRedirectUrl({
  required bool isWeb,
  required String configuredSiteUrl,
  String? webOrigin,
  String nativeDeepLink = hisabAuthCallbackDeepLink,
}) {
  if (!isWeb) return nativeDeepLink;

  final configured = configuredSiteUrl.trim();
  if (configured.isEmpty) return null;

  final configuredUri = Uri.tryParse(configured);
  final origin = webOrigin?.trim();
  if (configuredUri != null &&
      configuredUri.scheme == 'http' &&
      origin != null &&
      origin.startsWith('https://')) {
    final originUri = Uri.tryParse(origin);
    if (originUri != null && originUri.host == configuredUri.host) {
      return origin;
    }
  }
  return configured;
}
