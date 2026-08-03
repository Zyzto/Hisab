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
  // Already on the same invite/preview — keep token for post-auth auto-join.
  if (isInviteRoutePath(currentPath)) {
    final currentToken = inviteTokenFromPath(currentPath);
    if (currentToken == null || currentToken == pendingToken) return null;
    // Warm app received a different invite — navigate to the new token.
    return '/invite/$pendingToken';
  }
  return '/invite/$pendingToken';
}

/// Token segment from `/invite/<token>` or `/invite/<token>/...`; null for bare `/invite`.
String? inviteTokenFromPath(String path) {
  if (!isInviteRoutePath(path)) return null;
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.length < 2 || segments.first != 'invite') return null;
  final token = segments[1].trim();
  return token.isEmpty ? null : token;
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
  // Invites are entry flows — never restore them after process kill.
  if (isInviteRoutePath(lastPath)) return false;
  return true;
}

/// Whether a pending invite token should still force navigation to /invite.
/// Without auto-join (or mid-auth), a stale token alone must not bounce home.
bool shouldRedirectPendingInvite({
  required String pendingToken,
  required bool autoJoinFlag,
}) {
  if (pendingToken.isEmpty) return false;
  return autoJoinFlag;
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
