import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/auth/auth_flow_policy.dart';
import 'package:hisab/core/auth/sign_in_result.dart';
import 'package:hisab/core/constants/supabase_config.dart';

void main() {
  group('SignInResult caller contracts', () {
    test('only cancelled clears invite auto-join', () {
      for (final result in SignInResult.values) {
        expect(
          signInResultClearsInviteAutoJoin(result),
          result == SignInResult.cancelled,
          reason: '$result',
        );
      }
    });

    test('pendingRedirect and pendingEmailLink are auth-pending', () {
      expect(signInResultIsPending(SignInResult.pendingRedirect), isTrue);
      expect(signInResultIsPending(SignInResult.pendingEmailLink), isTrue);
      expect(signInResultIsPending(SignInResult.success), isFalse);
      expect(signInResultIsPending(SignInResult.cancelled), isFalse);
    });

    test('online pending flags set for email/OAuth pending only', () {
      for (final result in SignInResult.values) {
        expect(
          signInResultSetsOnlinePending(result),
          signInResultIsPending(result),
          reason: '$result',
        );
      }
    });

    test('invite Join matrix: keep auto-join through email/OAuth pending', () {
      // Documented contract used by invite_accept_page sign-in helpers.
      const keep = {
        SignInResult.success,
        SignInResult.pendingRedirect,
        SignInResult.pendingEmailLink,
      };
      for (final result in SignInResult.values) {
        final clears = signInResultClearsInviteAutoJoin(result);
        if (keep.contains(result)) {
          expect(clears, isFalse, reason: '$result must keep auto-join');
        } else {
          expect(clears, isTrue, reason: '$result must clear auto-join');
        }
      }
    });

    test('onboarding/settings matrix: pending results set online_pending', () {
      expect(signInResultSetsOnlinePending(SignInResult.pendingEmailLink), isTrue);
      expect(signInResultSetsOnlinePending(SignInResult.pendingRedirect), isTrue);
      expect(signInResultSetsOnlinePending(SignInResult.success), isFalse);
      expect(signInResultSetsOnlinePending(SignInResult.cancelled), isFalse);
    });
  });

  group('resolveSignInSheetDismiss', () {
    test('plain dismiss → cancelled', () {
      expect(
        resolveSignInSheetDismiss(emailLinkPending: false),
        SignInResult.cancelled,
      );
    });

    test('dismiss after magic/confirm email → pendingEmailLink', () {
      expect(
        resolveSignInSheetDismiss(emailLinkPending: true),
        SignInResult.pendingEmailLink,
      );
    });
  });

  group('resolveAuthRedirectUrl', () {
    test('native always uses OAuth/magic deep link', () {
      expect(
        resolveAuthRedirectUrl(
          isWeb: false,
          configuredSiteUrl: 'https://hisab.shenepoy.com',
        ),
        authOAuthCallbackDeepLink,
      );
      expect(
        resolveAuthRedirectUrl(isWeb: false, configuredSiteUrl: ''),
        'io.supabase.hisab://callback',
      );
    });

    test('web empty SITE_URL → null (Supabase Site URL fallback)', () {
      expect(
        resolveAuthRedirectUrl(isWeb: true, configuredSiteUrl: ''),
        isNull,
      );
      expect(
        resolveAuthRedirectUrl(isWeb: true, configuredSiteUrl: '   '),
        isNull,
      );
    });

    test('web uses configured SITE_URL as-is when https', () {
      expect(
        resolveAuthRedirectUrl(
          isWeb: true,
          configuredSiteUrl: 'https://hisab.shenepoy.com',
          webOrigin: 'https://hisab.shenepoy.com',
        ),
        'https://hisab.shenepoy.com',
      );
    });

    test('web upgrades http SITE_URL to https origin on same host', () {
      expect(
        resolveAuthRedirectUrl(
          isWeb: true,
          configuredSiteUrl: 'http://hisab.shenepoy.com',
          webOrigin: 'https://hisab.shenepoy.com',
        ),
        'https://hisab.shenepoy.com',
      );
    });

    test('web does not upgrade when hosts differ', () {
      expect(
        resolveAuthRedirectUrl(
          isWeb: true,
          configuredSiteUrl: 'http://localhost:8080',
          webOrigin: 'https://hisab.shenepoy.com',
        ),
        'http://localhost:8080',
      );
    });

    test('web does not upgrade when origin is still http', () {
      expect(
        resolveAuthRedirectUrl(
          isWeb: true,
          configuredSiteUrl: 'http://hisab.shenepoy.com',
          webOrigin: 'http://hisab.shenepoy.com',
        ),
        'http://hisab.shenepoy.com',
      );
    });
  });

  group('end-to-end flow tables', () {
    test('invite → magic link → dismiss sheet keeps join intent', () {
      final afterSend = resolveSignInSheetDismiss(emailLinkPending: true);
      expect(afterSend, SignInResult.pendingEmailLink);
      expect(signInResultClearsInviteAutoJoin(afterSend), isFalse);
      expect(signInResultIsPending(afterSend), isTrue);
    });

    test('invite → cancel before send clears join intent', () {
      final cancelled = resolveSignInSheetDismiss(emailLinkPending: false);
      expect(cancelled, SignInResult.cancelled);
      expect(signInResultClearsInviteAutoJoin(cancelled), isTrue);
    });

    test('onboarding → magic link sets online pending (not complete yet)', () {
      final pending = SignInResult.pendingEmailLink;
      expect(signInResultSetsOnlinePending(pending), isTrue);
      expect(signInResultIsPending(pending), isTrue);
    });

    test('settings → web OAuth pending sets online pending', () {
      expect(
        signInResultSetsOnlinePending(SignInResult.pendingRedirect),
        isTrue,
      );
    });

    test('native email auth redirect points at app callback', () {
      // Magic link / signup / resend / OAuth all share this on native.
      expect(
        resolveAuthRedirectUrl(isWeb: false, configuredSiteUrl: ''),
        authOAuthCallbackDeepLink,
      );
    });
  });
}
