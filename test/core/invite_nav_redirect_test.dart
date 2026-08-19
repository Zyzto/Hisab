import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/navigation/invite_nav_redirect.dart';

void main() {
  group('pendingInviteRedirectTarget', () {
    test('empty token → stay', () {
      expect(
        pendingInviteRedirectTarget(
          pendingToken: '',
          currentPath: '/',
          onOnboarding: false,
          onPrivacyPolicy: false,
        ),
        isNull,
      );
    });

    test('pending + home → invite accept', () {
      expect(
        pendingInviteRedirectTarget(
          pendingToken: 'tok-abc',
          currentPath: '/',
          onOnboarding: false,
          onPrivacyPolicy: false,
        ),
        '/invite/tok-abc',
      );
    });

    test('pending + settings → invite accept', () {
      expect(
        pendingInviteRedirectTarget(
          pendingToken: 'tok',
          currentPath: '/settings',
          onOnboarding: false,
          onPrivacyPolicy: false,
        ),
        '/invite/tok',
      );
    });

    test('pending while on onboarding → stay (do not steal register)', () {
      expect(
        pendingInviteRedirectTarget(
          pendingToken: 'tok',
          currentPath: '/onboarding',
          onOnboarding: true,
          onPrivacyPolicy: false,
        ),
        isNull,
      );
    });

    test('pending while on onboarding/connect → stay', () {
      expect(
        pendingInviteRedirectTarget(
          pendingToken: 'tok',
          currentPath: '/onboarding/connect',
          onOnboarding: true,
          onPrivacyPolicy: false,
        ),
        isNull,
      );
    });

    test('pending while on privacy → stay', () {
      expect(
        pendingInviteRedirectTarget(
          pendingToken: 'tok',
          currentPath: '/privacy-policy',
          onOnboarding: false,
          onPrivacyPolicy: true,
        ),
        isNull,
      );
    });

    test('already on /invite/<token> → stay (keep token for auto-join)', () {
      expect(
        pendingInviteRedirectTarget(
          pendingToken: 'tok',
          currentPath: '/invite/tok',
          onOnboarding: false,
          onPrivacyPolicy: false,
        ),
        isNull,
      );
    });

    test('already on bare /invite → stay (query-token form)', () {
      expect(
        pendingInviteRedirectTarget(
          pendingToken: 'tok',
          currentPath: '/invite',
          onOnboarding: false,
          onPrivacyPolicy: false,
        ),
        isNull,
      );
    });

    test('already on /invite/<token>/preview → stay', () {
      expect(
        pendingInviteRedirectTarget(
          pendingToken: 'tok',
          currentPath: '/invite/tok/preview',
          onOnboarding: false,
          onPrivacyPolicy: false,
        ),
        isNull,
      );
    });

    test('different invite path → navigate to pending token', () {
      expect(
        pendingInviteRedirectTarget(
          pendingToken: 'tok-a',
          currentPath: '/invite/tok-b',
          onOnboarding: false,
          onPrivacyPolicy: false,
        ),
        '/invite/tok-a',
      );
    });

    test('leftover pending after accept would bounce group detail → invite '
        '(must clear pending before leaving /invite)', () {
      expect(
        pendingInviteRedirectTarget(
          pendingToken: 'tok',
          currentPath: '/groups/group-1',
          onOnboarding: false,
          onPrivacyPolicy: false,
        ),
        '/invite/tok',
      );
    });
  });

  group('shouldRestoreLastRoute', () {
    test(
      'restores non-home last path when onboarded and no pending invite',
      () {
        expect(
          shouldRestoreLastRoute(
            lastPath: '/groups/g1',
            pendingToken: '',
            onboardingCompleted: true,
          ),
          isTrue,
        );
      },
    );

    test('pending invite wins over last-route restore', () {
      expect(
        shouldRestoreLastRoute(
          lastPath: '/groups/g1',
          pendingToken: 'tok',
          onboardingCompleted: true,
        ),
        isFalse,
      );
    });

    test('home last path is ignored', () {
      expect(
        shouldRestoreLastRoute(
          lastPath: '/',
          pendingToken: '',
          onboardingCompleted: true,
        ),
        isFalse,
      );
    });

    test('not onboarded → no restore', () {
      expect(
        shouldRestoreLastRoute(
          lastPath: '/groups/g1',
          pendingToken: '',
          onboardingCompleted: false,
        ),
        isFalse,
      );
    });

    test('invite last path is never restored', () {
      expect(
        shouldRestoreLastRoute(
          lastPath: '/invite/tok',
          pendingToken: '',
          onboardingCompleted: true,
        ),
        isFalse,
      );
    });

    test('onboarding last path is never restored', () {
      expect(
        shouldRestoreLastRoute(
          lastPath: '/onboarding/welcome',
          pendingToken: '',
          onboardingCompleted: true,
        ),
        isFalse,
      );
      expect(
        shouldRestoreLastRoute(
          lastPath: '/onboarding',
          pendingToken: '',
          onboardingCompleted: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldRedirectPendingInvite', () {
    test('token + auto-join → true', () {
      expect(
        shouldRedirectPendingInvite(pendingToken: 'tok', autoJoinFlag: true),
        isTrue,
      );
    });

    test('token without auto-join → false', () {
      expect(
        shouldRedirectPendingInvite(pendingToken: 'tok', autoJoinFlag: false),
        isFalse,
      );
    });

    test('empty token → false', () {
      expect(
        shouldRedirectPendingInvite(pendingToken: '', autoJoinFlag: true),
        isFalse,
      );
    });
  });

  group('inviteTokenFromPath', () {
    test('extracts token from accept and preview paths', () {
      expect(inviteTokenFromPath('/invite/tok'), 'tok');
      expect(inviteTokenFromPath('/invite/tok/preview'), 'tok');
    });

    test('bare /invite → null', () {
      expect(inviteTokenFromPath('/invite'), isNull);
    });
  });

  group('afterOnboardingRedirectTarget', () {
    test('not completed → null', () {
      expect(
        afterOnboardingRedirectTarget(
          onboardingCompleted: false,
          onOnboarding: true,
          pendingToken: 'tok',
        ),
        isNull,
      );
    });

    test('completed but not on onboarding → null', () {
      expect(
        afterOnboardingRedirectTarget(
          onboardingCompleted: true,
          onOnboarding: false,
          pendingToken: 'tok',
        ),
        isNull,
      );
    });

    test('completed on onboarding with pending → invite', () {
      expect(
        afterOnboardingRedirectTarget(
          onboardingCompleted: true,
          onOnboarding: true,
          pendingToken: 'tok-new',
        ),
        '/invite/tok-new',
      );
    });

    test('completed on onboarding without pending → home', () {
      expect(
        afterOnboardingRedirectTarget(
          onboardingCompleted: true,
          onOnboarding: true,
          pendingToken: '',
        ),
        '/',
      );
    });
  });

  group('shouldAutoJoinInvite', () {
    const happy = (
      autoJoinFlag: true,
      isAuthenticated: true,
      localOnly: false,
      canAcceptInvite: true,
      alreadyAttempted: false,
    );

    test('happy path → true', () {
      expect(
        shouldAutoJoinInvite(
          autoJoinFlag: happy.autoJoinFlag,
          isAuthenticated: happy.isAuthenticated,
          localOnly: happy.localOnly,
          canAcceptInvite: happy.canAcceptInvite,
          alreadyAttempted: happy.alreadyAttempted,
        ),
        isTrue,
      );
    });

    test('flag off → false', () {
      expect(
        shouldAutoJoinInvite(
          autoJoinFlag: false,
          isAuthenticated: true,
          localOnly: false,
          canAcceptInvite: true,
          alreadyAttempted: false,
        ),
        isFalse,
      );
    });

    test('unauthenticated → false', () {
      expect(
        shouldAutoJoinInvite(
          autoJoinFlag: true,
          isAuthenticated: false,
          localOnly: false,
          canAcceptInvite: true,
          alreadyAttempted: false,
        ),
        isFalse,
      );
    });

    test('localOnly → false', () {
      expect(
        shouldAutoJoinInvite(
          autoJoinFlag: true,
          isAuthenticated: true,
          localOnly: true,
          canAcceptInvite: true,
          alreadyAttempted: false,
        ),
        isFalse,
      );
    });

    test('readonly_only (cannot accept) → false', () {
      expect(
        shouldAutoJoinInvite(
          autoJoinFlag: true,
          isAuthenticated: true,
          localOnly: false,
          canAcceptInvite: false,
          alreadyAttempted: false,
        ),
        isFalse,
      );
    });

    test('already attempted → false (no double accept)', () {
      expect(
        shouldAutoJoinInvite(
          autoJoinFlag: true,
          isAuthenticated: true,
          localOnly: false,
          canAcceptInvite: true,
          alreadyAttempted: true,
        ),
        isFalse,
      );
    });
  });

  group('isInviteRoutePath', () {
    test('matches /invite and /invite/...', () {
      expect(isInviteRoutePath('/invite'), isTrue);
      expect(isInviteRoutePath('/invite/tok'), isTrue);
      expect(isInviteRoutePath('/invite/tok/preview'), isTrue);
    });

    test('does not match scan-invite or unrelated paths', () {
      expect(isInviteRoutePath('/scan-invite'), isFalse);
      expect(isInviteRoutePath('/'), isFalse);
      expect(isInviteRoutePath('/onboarding'), isFalse);
      expect(isInviteRoutePath('/groups/1/invites'), isFalse);
    });
  });

  group('unauthenticatedAutoJoinResume', () {
    test('new user → signIn (skip onboarding)', () {
      expect(
        unauthenticatedAutoJoinResume(
          autoJoinFlag: true,
          isAuthenticated: false,
          localOnly: false,
          canAcceptInvite: true,
          alreadyAttempted: false,
        ),
        InviteUnauthResumeAction.signIn,
      );
    });

    test('returning user → signIn', () {
      expect(
        unauthenticatedAutoJoinResume(
          autoJoinFlag: true,
          isAuthenticated: false,
          localOnly: false,
          canAcceptInvite: true,
          alreadyAttempted: false,
        ),
        InviteUnauthResumeAction.signIn,
      );
    });

    test('flag off → none', () {
      expect(
        unauthenticatedAutoJoinResume(
          autoJoinFlag: false,
          isAuthenticated: false,
          localOnly: false,
          canAcceptInvite: true,
          alreadyAttempted: false,
        ),
        InviteUnauthResumeAction.none,
      );
    });

    test('already authenticated → none (handled by shouldAutoJoin)', () {
      expect(
        unauthenticatedAutoJoinResume(
          autoJoinFlag: true,
          isAuthenticated: true,
          localOnly: false,
          canAcceptInvite: true,
          alreadyAttempted: false,
        ),
        InviteUnauthResumeAction.none,
      );
    });

    test('localOnly → none', () {
      expect(
        unauthenticatedAutoJoinResume(
          autoJoinFlag: true,
          isAuthenticated: false,
          localOnly: true,
          canAcceptInvite: true,
          alreadyAttempted: false,
        ),
        InviteUnauthResumeAction.none,
      );
    });

    test('readonly_only → none', () {
      expect(
        unauthenticatedAutoJoinResume(
          autoJoinFlag: true,
          isAuthenticated: false,
          localOnly: false,
          canAcceptInvite: false,
          alreadyAttempted: false,
        ),
        InviteUnauthResumeAction.none,
      );
    });

    test('already attempted → none', () {
      expect(
        unauthenticatedAutoJoinResume(
          autoJoinFlag: true,
          isAuthenticated: false,
          localOnly: false,
          canAcceptInvite: true,
          alreadyAttempted: true,
        ),
        InviteUnauthResumeAction.none,
      );
    });
  });
}
