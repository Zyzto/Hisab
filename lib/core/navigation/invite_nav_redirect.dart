/// Pure redirect decisions for invite + onboarding resume.
/// Kept free of Flutter/Riverpod so edge cases can be unit-tested.
library;

/// True for `/invite` (query-token form) and `/invite/...` path forms.
/// Does not match `/scan-invite`.
bool isInviteRoutePath(String path) =>
    path == '/invite' || path.startsWith('/invite/');

/// Where to send the user when a pending invite token exists.
///
/// Returns:
/// - `null` — stay on current route (and usually keep the pending token)
/// - non-null path — navigate there (caller clears pending token when appropriate)
///
/// Pending invite must be evaluated before last-route restore (camera kill).
String? pendingInviteRedirectTarget({
  required String pendingToken,
  required String currentPath,
  required bool onOnboarding,
  required bool onPrivacyPolicy,
}) {
  if (pendingToken.isEmpty) return null;
  // Never yank the user off register/login or privacy.
  // (Cold-start invite links use InviteLinkHandler.go instead of this path.)
  if (onOnboarding || onPrivacyPolicy) return null;
  // Already on invite/preview — keep token for post-auth auto-join.
  if (isInviteRoutePath(currentPath)) return null;
  return '/invite/$pendingToken';
}

/// Whether a camera/process-kill route restore may run.
/// Pending invite always wins so Join→auth is not diverted to a stale path.
bool shouldRestoreLastRoute({
  required String lastPath,
  required String pendingToken,
  required bool onboardingCompleted,
}) {
  if (!onboardingCompleted) return false;
  if (pendingToken.isNotEmpty) return false;
  if (lastPath.isEmpty || lastPath == '/') return false;
  return true;
}

/// After onboarding is marked complete while still on an onboarding route.
String? afterOnboardingRedirectTarget({
  required bool onboardingCompleted,
  required bool onOnboarding,
  required String pendingToken,
}) {
  if (!onboardingCompleted || !onOnboarding) return null;
  if (pendingToken.isNotEmpty) {
    return '/invite/$pendingToken';
  }
  return '/';
}

/// Whether invite accept should auto-accept after auth.
bool shouldAutoJoinInvite({
  required bool autoJoinFlag,
  required bool isAuthenticated,
  required bool localOnly,
  required bool canAcceptInvite,
  required bool alreadyAttempted,
}) {
  if (alreadyAttempted) return false;
  if (!autoJoinFlag) return false;
  if (!isAuthenticated) return false;
  if (localOnly) return false;
  if (!canAcceptInvite) return false;
  return true;
}

/// Unauthenticated resume after Join from preview (auto-join already set).
enum InviteUnauthResumeAction { none, signIn }

InviteUnauthResumeAction unauthenticatedAutoJoinResume({
  required bool autoJoinFlag,
  required bool isAuthenticated,
  required bool localOnly,
  required bool canAcceptInvite,
  required bool alreadyAttempted,
}) {
  if (alreadyAttempted) return InviteUnauthResumeAction.none;
  if (!autoJoinFlag) return InviteUnauthResumeAction.none;
  if (isAuthenticated) return InviteUnauthResumeAction.none;
  if (localOnly) return InviteUnauthResumeAction.none;
  if (!canAcceptInvite) return InviteUnauthResumeAction.none;
  return InviteUnauthResumeAction.signIn;
}
