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

    test('different invite path still counts as invite route → stay', () {
      expect(
        pendingInviteRedirectTarget(
          pendingToken: 'tok-a',
          currentPath: '/invite/tok-b',
          onOnboarding: false,
          onPrivacyPolicy: false,
        ),
        isNull,
      );
    });

    test(
      'leftover pending after accept would bounce group detail → invite '
      '(must clear pending before leaving /invite)',
      () {
        expect(
          pendingInviteRedirectTarget(
            pendingToken: 'tok',
            currentPath: '/groups/group-1',
            onOnboarding: false,
            onPrivacyPolicy: false,
          ),
          '/invite/tok',
        );
      },
    );
  });

  group('shouldRestoreLastRoute', () {
    test('restores non-home last path when onboarded and no pending invite', () {
      expect(
        shouldRestoreLastRoute(
          lastPath: '/groups/g1',
          pendingToken: '',
          onboardingCompleted: true,
        ),
        isTrue,
      );
    });

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

  group('unauthenticatedAutoJoinResume', () {
    test('new user → onboarding', () {
      expect(
        unauthenticatedAutoJoinResume(
          autoJoinFlag: true,
          isAuthenticated: false,
          localOnly: false,
          canAcceptInvite: true,
          onboardingCompleted: false,
          alreadyAttempted: false,
        ),
        InviteUnauthResumeAction.onboarding,
      );
    });

    test('returning onboarded user → signIn (not onboarding→home bounce)', () {
      expect(
        unauthenticatedAutoJoinResume(
          autoJoinFlag: true,
          isAuthenticated: false,
          localOnly: false,
          canAcceptInvite: true,
          onboardingCompleted: true,
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
          onboardingCompleted: false,
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
          onboardingCompleted: true,
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
          onboardingCompleted: false,
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
          onboardingCompleted: false,
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
          onboardingCompleted: false,
          alreadyAttempted: true,
        ),
        InviteUnauthResumeAction.none,
      );
    });
  });
}
