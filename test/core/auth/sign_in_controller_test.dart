import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/auth/predefined_avatars.dart';
import 'package:hisab/core/auth/sign_in/auth_error_messages.dart';
import 'package:hisab/core/auth/sign_in/sign_in_controller.dart';
import 'package:hisab/core/auth/sign_in/sign_in_state.dart';
import 'package:hisab/core/auth/sign_in_result.dart';
import 'package:hisab_backend/hisab_backend.dart';

import 'fake_auth_service.dart';

void main() {
  late FakeAuthService auth;

  setUp(() => auth = FakeAuthService());
  tearDown(() => auth.close());

  SignInController build({
    bool isWeb = false,
    Duration timeout = const Duration(milliseconds: 200),
  }) {
    return SignInController(
      authService: auth,
      isWeb: isWeb,
      callbackTimeout: timeout,
    );
  }

  group('form interactions', () {
    test('starts on sign-in, first step, password hidden', () {
      final c = build();
      expect(c.state.mode, SignInMode.signIn);
      expect(c.state.signUpStep, SignUpStep.credentials);
      expect(c.state.obscurePassword, isTrue);
      expect(c.state.panel, SignInPanel.none);
      expect(c.state.emailLinkPending, isFalse);
      expect(c.state.outcome, isNull);
    });

    test('toggling mode clears the error and returns to step one', () {
      final c = build()
        ..selectAvatar('fox')
        ..toggleMode();
      expect(c.state.mode, SignInMode.signUp);

      c.goToProfileStep();
      expect(c.state.signUpStep, SignUpStep.profile);

      c.toggleMode();
      expect(c.state.mode, SignInMode.signIn);
      expect(c.state.signUpStep, SignUpStep.credentials);
      expect(c.state.selectedAvatarId, defaultAvatarId);
    });

    test('reveal toggle flips both ways and notifies', () {
      final c = build();
      var notifications = 0;
      c.addListener(() => notifications++);

      c.toggleObscurePassword();
      expect(c.state.obscurePassword, isFalse);
      c.toggleObscurePassword();
      expect(c.state.obscurePassword, isTrue);
      expect(notifications, 2);
    });

    test('profile step is unreachable while signing in', () {
      final c = build()..goToProfileStep();
      expect(c.state.signUpStep, SignUpStep.credentials);
    });

    test('back returns to the credentials step', () {
      final c = build()
        ..toggleMode()
        ..goToProfileStep()
        ..backToCredentials();
      expect(c.state.signUpStep, SignUpStep.credentials);
    });

    test('Done on an email panel resolves as pendingEmailLink', () {
      final c = build()..acknowledgePendingEmail();
      expect(c.state.outcome, SignInResult.pendingEmailLink);
      expect(c.state.emailLinkPending, isTrue);
    });
  });

  group('email sign-in', () {
    test('success finishes with SignInResult.success', () async {
      final c = build();
      await c.submit(email: 'a@b.co', password: 'secret1');

      expect(auth.calls, ['signInWithEmail']);
      expect(c.state.outcome, SignInResult.success);
      expect(c.state.busy, isFalse);
    });

    test('bad credentials surface an error and stay on the form', () async {
      auth.signInError = const CloudException('Invalid login credentials');
      final c = build();
      await c.submit(email: 'a@b.co', password: 'wrong1');

      expect(c.state.outcome, isNull);
      expect(c.state.errorKey, AuthErrorKeys.invalidCredentials);
      expect(c.state.busy, isFalse);
      expect(c.state.panel, SignInPanel.none);
    });

    test('unconfirmed email opens the confirm panel, not an error', () async {
      auth.signInError = const CloudException(
        'Email not confirmed',
        code: 'email_not_confirmed',
      );
      final c = build();
      await c.submit(email: 'a@b.co', password: 'secret1');

      expect(c.state.panel, SignInPanel.awaitingConfirmation);
      expect(c.state.errorKey, isNull);
      // Closing now must not read as a cancel — the link is already sent.
      expect(c.state.emailLinkPending, isTrue);
      expect(c.state.confirmationResent, isFalse);
    });

    test('a retry clears the previous error', () async {
      auth.signInError = const CloudException('Invalid login credentials');
      final c = build();
      await c.submit(email: 'a@b.co', password: 'wrong1');
      expect(c.state.errorKey, isNotNull);

      auth.signInError = null;
      await c.submit(email: 'a@b.co', password: 'secret1');
      expect(c.state.errorKey, isNull);
    });
  });

  group('email sign-up', () {
    test('a returned session signs the user straight in', () async {
      final c = build()..toggleMode();
      c.selectAvatar('fox');
      await c.submit(email: 'a@b.co', password: 'secret1', name: '  Sam  ');

      expect(auth.calls, ['signUpWithEmail']);
      expect(auth.lastSignUp?.name, 'Sam');
      expect(auth.lastSignUp?.avatarId, 'fox');
      expect(c.state.outcome, SignInResult.success);
    });

    test('a blank name is sent as null so the backend derives one', () async {
      final c = build()..toggleMode();
      await c.submit(email: 'a@b.co', password: 'secret1', name: '   ');
      expect(auth.lastSignUp?.name, isNull);
    });

    test('no session means confirmation is pending', () async {
      auth.signUpResponse = const CloudAuthResponse(user: kTestUser);
      final c = build()..toggleMode();
      await c.submit(email: 'a@b.co', password: 'secret1');

      expect(c.state.panel, SignInPanel.awaitingConfirmation);
      expect(c.state.emailLinkPending, isTrue);
      expect(c.state.outcome, isNull);
    });

    test('a duplicate address is an inline error', () async {
      auth.signUpError = const CloudException('User already registered');
      final c = build()..toggleMode();
      await c.submit(email: 'a@b.co', password: 'secret1');

      expect(c.state.errorKey, AuthErrorKeys.alreadyRegistered);
      expect(c.state.panel, SignInPanel.none);
    });
  });

  group('resend confirmation', () {
    test('marks the banner as resent', () async {
      final c = build();
      await c.resendConfirmation('a@b.co');
      expect(auth.calls, ['resendConfirmation']);
      expect(c.state.confirmationResent, isTrue);
      expect(c.state.errorKey, isNull);
    });

    test('a throttle still counts as sent', () async {
      // The user asked for an email and one went out recently; showing an
      // error here would tell them the opposite of what happened.
      auth.resendError = const CloudException(
        'over rate limit',
        code: 'over_email_send_rate_limit',
      );
      final c = build();
      await c.resendConfirmation('a@b.co');

      expect(c.state.confirmationResent, isTrue);
      expect(c.state.errorKey, isNull);
    });

    test('other failures surface an error', () async {
      auth.resendError = const CloudException('boom');
      final c = build();
      await c.resendConfirmation('a@b.co');

      expect(c.state.confirmationResent, isFalse);
      expect(c.state.errorKey, AuthErrorKeys.generic);
    });

    test('a blank address is a no-op', () async {
      final c = build();
      await c.resendConfirmation('   ');
      expect(auth.calls, isEmpty);
    });
  });

  group('magic link', () {
    test('web stops at the sent panel and waits for no callback', () async {
      final c = build(isWeb: true);
      await c.sendMagicLink('a@b.co');

      expect(c.state.panel, SignInPanel.magicLinkSent);
      expect(c.state.emailLinkPending, isTrue);
      expect(c.state.busy, isFalse);
      expect(c.state.outcome, isNull);
    });

    test('native keeps waiting and completes on the deep link', () async {
      auth.emitSignedInAfterLaunch = true;
      final c = build();
      await c.sendMagicLink('a@b.co');

      expect(c.state.outcome, SignInResult.success);
      expect(c.state.emailLinkPending, isTrue);
    });

    test('native times out with a retryable error', () async {
      final c = build(timeout: const Duration(milliseconds: 20));
      await c.sendMagicLink('a@b.co');

      expect(c.state.errorKey, AuthErrorKeys.oauthTimeout);
      expect(c.state.busy, isFalse);
      // The panel stays: the emailed link may still arrive later.
      expect(c.state.panel, SignInPanel.magicLinkSent);
      expect(c.state.emailLinkPending, isTrue);
    });

    test('an already-signed-in native session short-circuits', () async {
      auth.authenticated = true;
      final c = build();
      await c.sendMagicLink('a@b.co');

      expect(auth.calls, isEmpty);
      expect(c.state.outcome, SignInResult.success);
    });

    test('a send failure is an inline error with no panel', () async {
      auth.magicLinkError = const CloudException('boom');
      final c = build();
      await c.sendMagicLink('a@b.co');

      expect(c.state.errorKey, AuthErrorKeys.generic);
      expect(c.state.panel, SignInPanel.none);
      expect(c.state.emailLinkPending, isFalse);
    });
  });

  group('password reset', () {
    test('shows the sent panel and marks an email as pending', () async {
      final c = build();
      await c.sendPasswordReset('a@b.co');

      expect(auth.calls, ['requestPasswordReset']);
      expect(c.state.panel, SignInPanel.resetSent);
      expect(c.state.busy, isFalse);
      expect(c.state.errorKey, isNull);
      // A recovery link establishes a real session, so a dismiss from here is
      // pending rather than cancelled and the caller keeps its intent.
      expect(c.state.emailLinkPending, isTrue);
    });

    test('never waits for a callback, even on native', () async {
      // A three-minute wait would be wrong here: the recovery link reopens the
      // app into the change-password sheet, not back into this one.
      final c = build(timeout: const Duration(seconds: 30));
      await c.sendPasswordReset('a@b.co').timeout(const Duration(seconds: 1));
      expect(c.state.outcome, isNull);
      expect(c.state.busy, isFalse);
    });

    test('Done then resolves as pendingEmailLink', () async {
      final c = build();
      await c.sendPasswordReset('a@b.co');
      c.acknowledgePendingEmail();
      expect(c.state.outcome, SignInResult.pendingEmailLink);
    });

    test('a throttle is surfaced so the user knows to wait', () async {
      auth.resetError = const CloudException(
        'over rate limit',
        code: 'over_email_send_rate_limit',
      );
      final c = build();
      await c.sendPasswordReset('a@b.co');

      expect(c.state.errorKey, AuthErrorKeys.rateLimit);
      expect(c.state.panel, SignInPanel.none);
      expect(c.state.emailLinkPending, isFalse);
    });
  });

  group('oauth', () {
    test('web reports pendingRedirect once the page navigates', () async {
      final c = build(isWeb: true);
      await c.signInWithProvider(CloudOAuthProvider.google);

      expect(auth.calls, ['signInWithGoogle']);
      expect(c.state.outcome, SignInResult.pendingRedirect);
    });

    test('native completes on the callback', () async {
      auth.emitSignedInAfterLaunch = true;
      final c = build();
      await c.signInWithProvider(CloudOAuthProvider.github);

      expect(auth.calls, ['signInWithGithub']);
      expect(c.state.outcome, SignInResult.success);
    });

    test('a browser that never opened is reported, not awaited', () async {
      auth.oauthLaunched = false;
      final c = build(timeout: const Duration(seconds: 30));
      await c.signInWithProvider(CloudOAuthProvider.google);

      expect(c.state.errorKey, AuthErrorKeys.oauthFailed);
      expect(c.state.busy, isFalse);
    });

    test('native times out with a retryable error', () async {
      final c = build(timeout: const Duration(milliseconds: 20));
      await c.signInWithProvider(CloudOAuthProvider.google);

      expect(c.state.errorKey, AuthErrorKeys.oauthTimeout);
      expect(c.state.busy, isFalse);
    });

    test('a launch throw becomes an inline error', () async {
      auth.oauthError = const CloudException('boom');
      final c = build();
      await c.signInWithProvider(CloudOAuthProvider.google);

      expect(c.state.errorKey, AuthErrorKeys.generic);
    });

    test('never reports pendingRedirect on native', () async {
      final c = build(timeout: const Duration(milliseconds: 20));
      await c.signInWithProvider(CloudOAuthProvider.google);
      expect(c.state.outcome, isNull);
    });
  });

  group('native google', () {
    test('succeeds without opening a browser', () async {
      auth.nativeGoogleOutcome = NativeGoogleOutcome.signedIn;
      final c = build();
      await c.signInWithProvider(CloudOAuthProvider.google);

      // No signInWithGoogle: the ID token exchange already made a session, so
      // there is nothing to wait for.
      expect(auth.calls, ['signInWithNativeGoogle']);
      expect(c.state.outcome, SignInResult.success);
      expect(c.state.busy, isFalse);
    });

    test('dismissing the picker returns to the form without an error', () async {
      auth.nativeGoogleOutcome = NativeGoogleOutcome.cancelled;
      final c = build();
      await c.signInWithProvider(CloudOAuthProvider.google);

      expect(auth.calls, ['signInWithNativeGoogle']);
      expect(c.state.errorKey, isNull);
      expect(c.state.outcome, isNull);
      expect(c.state.busy, isFalse);
    });

    test('unsupported falls back to the browser', () async {
      auth.nativeGoogleOutcome = NativeGoogleOutcome.unsupported;
      auth.emitSignedInAfterLaunch = true;
      final c = build();
      await c.signInWithProvider(CloudOAuthProvider.google);

      expect(auth.calls, ['signInWithNativeGoogle', 'signInWithGoogle']);
      expect(c.state.outcome, SignInResult.success);
    });

    test('a misconfigured picker falls back instead of failing', () async {
      // A missing SHA-1 fingerprint throws here, but the browser flow reaches
      // the same provider, so the user should never see it.
      auth.nativeGoogleError = const CloudException('DEVELOPER_ERROR');
      auth.emitSignedInAfterLaunch = true;
      final c = build();
      await c.signInWithProvider(CloudOAuthProvider.google);

      expect(auth.calls, ['signInWithNativeGoogle', 'signInWithGoogle']);
      expect(c.state.errorKey, isNull);
      expect(c.state.outcome, SignInResult.success);
    });

    test('web skips the picker entirely', () async {
      auth.nativeGoogleOutcome = NativeGoogleOutcome.signedIn;
      final c = build(isWeb: true);
      await c.signInWithProvider(CloudOAuthProvider.google);

      expect(auth.calls, ['signInWithGoogle']);
      expect(c.state.outcome, SignInResult.pendingRedirect);
    });

    test('github never tries the picker', () async {
      auth.nativeGoogleOutcome = NativeGoogleOutcome.signedIn;
      auth.emitSignedInAfterLaunch = true;
      final c = build();
      await c.signInWithProvider(CloudOAuthProvider.github);

      expect(auth.calls, ['signInWithGithub']);
    });
  });

  group('dismiss semantics', () {
    test('nothing sent yet means a dismiss is a real cancel', () async {
      final c = build();
      await c.submit(email: 'a@b.co', password: 'secret1');
      // Success sets an outcome, so start over for the untouched case.
      final fresh = build();
      expect(fresh.state.emailLinkPending, isFalse);
      expect(c.state.emailLinkPending, isFalse);
    });

    test('gesture dismissal is blocked mid-request but not while waiting', () {
      final c = build();
      expect(c.state.canPop, isTrue);
      expect(
        const SignInFormState(busy: true).canPop,
        isFalse,
        reason: 'a request is in flight',
      );
      expect(
        const SignInFormState(
          busy: true,
          panel: SignInPanel.magicLinkSent,
        ).canPop,
        isTrue,
        reason: 'waiting on an email must not trap the user',
      );
    });
  });
}
