/// Pure auth-flow decisions shared by the sign-in sheet and its callers.
/// Kept free of Flutter/Riverpod so login + invite resume can be unit-tested.
library;

import '../constants/supabase_config.dart';
import 'sign_in_result.dart';

/// True when auth was started but the session is not ready yet (web OAuth
/// reload or email magic/confirm link still outstanding).
bool signInResultIsPending(SignInResult result) =>
    result == SignInResult.pendingRedirect ||
    result == SignInResult.pendingEmailLink;

/// Invite Join must keep `pending_invite_auto_join` for every result except
/// an explicit user cancel before email/OAuth is in flight.
bool signInResultClearsInviteAutoJoin(SignInResult result) =>
    result == SignInResult.cancelled;

/// Onboarding / settings "switch to online" persist a pending flag for these
/// results so cold start or warm resume can finish after the email/OAuth return.
bool signInResultSetsOnlinePending(SignInResult result) =>
    signInResultIsPending(result);

/// Barrier/back dismiss mapping for [showSignInSheet] when the sheet returns
/// null. After magic-link / confirm-email UI, dismiss must not look like cancel.
SignInResult resolveSignInSheetDismiss({required bool emailLinkPending}) =>
    emailLinkPending ? SignInResult.pendingEmailLink : SignInResult.cancelled;

/// Platform redirect for OAuth + email auth (`emailRedirectTo` / `redirectTo`).
///
/// - Web: [configuredSiteUrl] (SITE_URL), with http→https upgrade when the live
///   [webOrigin] is already https on the same host.
/// - Native: [nativeDeepLink] so PKCE verifier stays in the app.
String? resolveAuthRedirectUrl({
  required bool isWeb,
  required String configuredSiteUrl,
  String? webOrigin,
  String nativeDeepLink = authOAuthCallbackDeepLink,
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
