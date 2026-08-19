/// Pure auth-flow decisions shared by the sign-in sheet and its callers.
/// Kept free of Flutter/Riverpod so login + invite resume can be unit-tested.
library;

import 'sign_in_result.dart';

/// Redirect resolution lives in the backend contract because a backend has to
/// allowlist the exact values it produces. Re-exported so callers and tests see
/// one auth-policy surface.
export 'package:hisab_backend/hisab_backend.dart'
    show
        hisabAuthCallbackDeepLink,
        legacyHisabAuthCallbackDeepLink,
        resolveAuthRedirectUrl;

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

/// Query or fragment params that mean this load is an OAuth / magic-link return.
const authCallbackParamKeys = {
  'code',
  'access_token',
  'error',
  'error_code',
  'error_description',
};

/// True when [uri] is a backend auth callback, including hash fragments.
bool uriLooksLikeAuthCallback(Uri uri) {
  final fragment = uri.fragment.isEmpty
      ? const <String, String>{}
      : Uri.splitQueryString(uri.fragment);
  return authCallbackParamKeys.any(
    (key) => uri.queryParameters.containsKey(key) || fragment.containsKey(key),
  );
}
