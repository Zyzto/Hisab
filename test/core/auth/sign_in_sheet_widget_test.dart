import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab_backend/hisab_backend.dart';

import 'package:hisab/core/auth/auth_providers.dart';
import 'package:hisab/core/auth/sign_in/widgets/auth_brand_panel.dart';
import 'package:hisab/core/auth/sign_in_sheet.dart';
import 'package:hisab/core/widgets/app_brand_mark.dart';

import '../../widget_test_helpers.dart';
import 'fake_auth_service.dart';

/// Under `flutter test` easy_localization resolves to the raw key, so finders
/// match key strings rather than English copy.
void main() {
  setUpAll(() => EasyLocalization.logger.enableBuildModes = []);

  late FakeAuthService auth;
  SignInResult? result;

  setUp(() {
    auth = FakeAuthService();
    result = null;
  });
  tearDown(() => auth.close());

  void setPhoneViewport(WidgetTester tester) {
    // Tall enough that the whole form is on screen, so taps do not need
    // scrolling gymnastics.
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Wide enough for the dialog to earn its 880px cap and the brand panel.
  void setDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openSheet(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (ctx, ref, _) => FilledButton(
                onPressed: () async {
                  result = await showSignInSheet(ctx, ref);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder primaryButton(String label) =>
      find.widgetWithText(FilledButton, label);

  Future<void> enterCredentials(
    WidgetTester tester, {
    String email = 'a@b.co',
    String password = 'secret1',
  }) async {
    await tester.enterText(find.byType(TextFormField).first, email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.pumpAndSettle();
  }

  testWidgets('opens in sign-in mode with both OAuth providers', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await openSheet(tester);

    expect(find.text('auth_provider_google'), findsOneWidget);
    expect(find.text('auth_provider_github'), findsOneWidget);
    expect(find.text('auth_email'), findsOneWidget);
    expect(find.text('auth_password'), findsOneWidget);
    expect(find.text('auth_magic_link'), findsOneWidget);
    expect(primaryButton('sign_in'), findsOneWidget);
  });

  testWidgets('toggling to sign-up swaps the CTA and hides magic link', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await openSheet(tester);

    await tester.tap(find.widgetWithText(TextButton, 'auth_sign_up'));
    await tester.pumpAndSettle();

    expect(primaryButton('auth_continue'), findsOneWidget);
    expect(find.text('auth_magic_link'), findsNothing);
    expect(find.widgetWithText(TextButton, 'sign_in'), findsOneWidget);
  });

  testWidgets('submitting a blank form validates instead of calling the API', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await openSheet(tester);

    await tester.tap(primaryButton('sign_in'));
    await tester.pumpAndSettle();

    expect(find.text('required'), findsNWidgets(2));
    expect(auth.calls, isEmpty);
  });

  testWidgets('a malformed address is rejected inline', (tester) async {
    setPhoneViewport(tester);
    await openSheet(tester);
    await enterCredentials(tester, email: 'not-an-email');

    await tester.tap(primaryButton('sign_in'));
    await tester.pumpAndSettle();

    expect(find.text('auth_invalid_email'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('a short password is rejected inline', (tester) async {
    setPhoneViewport(tester);
    await openSheet(tester);
    await enterCredentials(tester, password: 'abc');

    await tester.tap(primaryButton('sign_in'));
    await tester.pumpAndSettle();

    expect(find.text('auth_password_too_short'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('the reveal toggle unmasks the password field', (tester) async {
    setPhoneViewport(tester);
    await openSheet(tester);

    EditableText passwordField() =>
        tester.widget<EditableText>(find.byType(EditableText).at(1));

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();
    expect(passwordField().obscureText, isFalse);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();
    expect(passwordField().obscureText, isTrue);
  });

  testWidgets('sign-up Continue advances to the profile step and back', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await openSheet(tester);
    await tester.tap(find.widgetWithText(TextButton, 'auth_sign_up'));
    await tester.pumpAndSettle();
    await enterCredentials(tester);

    await tester.tap(primaryButton('auth_continue'));
    await tester.pumpAndSettle();

    expect(find.text('auth_avatar'), findsOneWidget);
    expect(primaryButton('auth_create_account'), findsOneWidget);
    // Step two is only about the profile, so the account fields are gone.
    expect(find.text('auth_provider_google'), findsNothing);
    expect(find.text('auth_password'), findsNothing);
    expect(auth.calls, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'auth_back'));
    await tester.pumpAndSettle();

    expect(primaryButton('auth_continue'), findsOneWidget);
    expect(find.text('auth_provider_google'), findsOneWidget);
  });

  testWidgets('invalid credentials never reach the profile step', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await openSheet(tester);
    await tester.tap(find.widgetWithText(TextButton, 'auth_sign_up'));
    await tester.pumpAndSettle();
    await enterCredentials(tester, email: 'bad');

    await tester.tap(primaryButton('auth_continue'));
    await tester.pumpAndSettle();

    expect(find.text('auth_avatar'), findsNothing);
    expect(find.text('auth_invalid_email'), findsOneWidget);
  });

  testWidgets('a successful sign-in closes with success', (tester) async {
    setPhoneViewport(tester);
    await openSheet(tester);
    await enterCredentials(tester);

    await tester.tap(primaryButton('sign_in'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signInWithEmail']);
    expect(result, SignInResult.success);
  });

  testWidgets('a rejected sign-in shows the error and stays open', (
    tester,
  ) async {
    auth.signInError = const CloudException('Invalid login credentials');
    setPhoneViewport(tester);
    await openSheet(tester);
    await enterCredentials(tester);

    await tester.tap(primaryButton('sign_in'));
    await tester.pumpAndSettle();

    expect(find.text('auth_invalid_credentials'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('sign-up needing confirmation ends as pendingEmailLink', (
    tester,
  ) async {
    auth.signUpResponse = const CloudAuthResponse(user: kTestUser);
    setPhoneViewport(tester);
    await openSheet(tester);
    await tester.tap(find.widgetWithText(TextButton, 'auth_sign_up'));
    await tester.pumpAndSettle();
    await enterCredentials(tester);
    await tester.tap(primaryButton('auth_continue'));
    await tester.pumpAndSettle();

    await tester.tap(primaryButton('auth_create_account'));
    await tester.pumpAndSettle();

    expect(find.text('auth_email_not_confirmed'), findsOneWidget);
    expect(find.text('auth_resend_confirmation'), findsOneWidget);

    await tester.tap(primaryButton('done'));
    await tester.pumpAndSettle();

    expect(result, SignInResult.pendingEmailLink);
  });

  testWidgets('dismissing after a sent email is not a cancel', (tester) async {
    auth.signUpResponse = const CloudAuthResponse(user: kTestUser);
    setPhoneViewport(tester);
    await openSheet(tester);
    await tester.tap(find.widgetWithText(TextButton, 'auth_sign_up'));
    await tester.pumpAndSettle();
    await enterCredentials(tester);
    await tester.tap(primaryButton('auth_continue'));
    await tester.pumpAndSettle();
    await tester.tap(primaryButton('auth_create_account'));
    await tester.pumpAndSettle();

    // Barrier tap, the same gesture as swiping the sheet away.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, SignInResult.pendingEmailLink);
  });

  testWidgets('forgot password needs only a valid address', (tester) async {
    setPhoneViewport(tester);
    await openSheet(tester);

    await tester.enterText(find.byType(TextFormField).first, 'bad');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'auth_forgot_password'));
    await tester.pumpAndSettle();
    expect(find.text('auth_invalid_email'), findsOneWidget);
    expect(auth.calls, isEmpty);

    await tester.enterText(find.byType(TextFormField).first, 'a@b.co');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'auth_forgot_password'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['requestPasswordReset']);
    expect(find.text('auth_reset_sent'), findsOneWidget);
  });

  testWidgets('forgot password is hidden while signing up', (tester) async {
    setPhoneViewport(tester);
    await openSheet(tester);
    await tester.tap(find.widgetWithText(TextButton, 'auth_sign_up'));
    await tester.pumpAndSettle();

    expect(find.text('auth_forgot_password'), findsNothing);
  });

  testWidgets('closing after a reset email is not a cancel', (tester) async {
    setPhoneViewport(tester);
    await openSheet(tester);
    await tester.enterText(find.byType(TextFormField).first, 'a@b.co');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'auth_forgot_password'));
    await tester.pumpAndSettle();

    await tester.tap(primaryButton('done'));
    await tester.pumpAndSettle();

    expect(result, SignInResult.pendingEmailLink);
  });

  testWidgets('dismissing before anything is sent is a cancel', (tester) async {
    setPhoneViewport(tester);
    await openSheet(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, SignInResult.cancelled);
  });

  group('identity', () {
    testWidgets('the hero carries the app mark and a headline per state', (
      tester,
    ) async {
      setPhoneViewport(tester);
      await openSheet(tester);

      expect(find.byType(AppBrandMark), findsOneWidget);
      expect(find.text('auth_welcome_back'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'auth_sign_up'));
      await tester.pumpAndSettle();
      expect(find.text('auth_create_account_title'), findsOneWidget);
      expect(find.text('auth_welcome_back'), findsNothing);

      await enterCredentials(tester);
      await tester.tap(primaryButton('auth_continue'));
      await tester.pumpAndSettle();
      expect(find.text('auth_almost_there'), findsOneWidget);
      // The mark stays put rather than flashing out between steps.
      expect(find.byType(AppBrandMark), findsOneWidget);
    });

    testWidgets('the divider names email as the alternative', (tester) async {
      setPhoneViewport(tester);
      await openSheet(tester);

      expect(find.text('auth_or_email'), findsOneWidget);
    });

    testWidgets('the fields carry no prefix icons', (tester) async {
      setPhoneViewport(tester);
      await openSheet(tester);

      // An envelope and a padlock beside labelled fields say nothing the labels
      // do not, and they made the form outshout the headline above it.
      expect(find.byIcon(Icons.email_outlined), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      // The one icon that does earn its place stays.
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('a phone gets no brand panel', (tester) async {
      setPhoneViewport(tester);
      await openSheet(tester);

      expect(find.byType(AuthBrandPanel), findsNothing);
      expect(find.byType(AppBrandMark), findsOneWidget);
    });

    testWidgets('a desktop viewport gets the brand panel and one mark', (
      tester,
    ) async {
      setDesktopViewport(tester);
      await openSheet(tester);

      expect(find.byType(AuthBrandPanel), findsOneWidget);
      // The panel carries the mark, so the hero drops its own rather than
      // showing the logo twice on one dialog.
      expect(find.byType(AppBrandMark), findsOneWidget);
      expect(find.text('auth_brand_tagline'), findsOneWidget);
      // The form is still fully there beside it.
      expect(find.text('auth_welcome_back'), findsOneWidget);
      expect(primaryButton('sign_in'), findsOneWidget);
    });
  });

  group('recovering from a dead end', () {
    testWidgets('a sent email echoes the address it went to', (tester) async {
      setPhoneViewport(tester);
      await openSheet(tester);
      await tester.enterText(
        find.byType(TextFormField).first,
        'typo@exampl.co',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'auth_forgot_password'));
      await tester.pumpAndSettle();

      // Without this the user cannot tell a mistyped domain from a slow inbox.
      expect(find.text('auth_check_email'), findsOneWidget);
      expect(find.text('typo@exampl.co'), findsOneWidget);
    });

    testWidgets('a rejected password points at the provider buttons', (
      tester,
    ) async {
      auth.signInError = const CloudException('Invalid login credentials');
      setPhoneViewport(tester);
      await openSheet(tester);
      await enterCredentials(tester);

      await tester.tap(primaryButton('sign_in'));
      await tester.pumpAndSettle();

      expect(find.text('auth_provider_hint'), findsOneWidget);
    });

    testWidgets('other failures do not blame the providers', (tester) async {
      auth.signInError = const CloudException('boom');
      setPhoneViewport(tester);
      await openSheet(tester);
      await enterCredentials(tester);

      await tester.tap(primaryButton('sign_in'));
      await tester.pumpAndSettle();

      expect(find.text('auth_generic_error'), findsOneWidget);
      expect(find.text('auth_provider_hint'), findsNothing);
    });
  });

  group('sign-up guidance', () {
    testWidgets('the step counter tracks both steps and only sign-up', (
      tester,
    ) async {
      setPhoneViewport(tester);
      await openSheet(tester);

      expect(find.text('auth_step_of'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'auth_sign_up'));
      await tester.pumpAndSettle();
      expect(find.text('auth_step_of'), findsOneWidget);
      expect(filledStepBars(tester), 1);

      await enterCredentials(tester);
      await tester.tap(primaryButton('auth_continue'));
      await tester.pumpAndSettle();
      expect(filledStepBars(tester), 2);
    });

    testWidgets('the password rule is stated before it is enforced', (
      tester,
    ) async {
      setPhoneViewport(tester);
      await openSheet(tester);

      // Nothing to explain when signing in to an account that already exists.
      expect(passwordDecoration(tester).helperText, isNull);

      await tester.tap(find.widgetWithText(TextButton, 'auth_sign_up'));
      await tester.pumpAndSettle();

      expect(passwordDecoration(tester).helperText, 'auth_password_hint');
    });
  });

  group('password managers', () {
    testWidgets('the fields share one autofill context', (tester) async {
      setPhoneViewport(tester);
      await openSheet(tester);

      // Without a common group the platform sees two unrelated fields and
      // never offers to save the pair.
      expect(find.byType(AutofillGroup), findsOneWidget);
      expect(emailField(tester).autofillHints, [AutofillHints.email]);
    });

    testWidgets('signing up asks for a generated password, not a saved one', (
      tester,
    ) async {
      setPhoneViewport(tester);
      await openSheet(tester);

      expect(passwordField(tester).autofillHints, [AutofillHints.password]);

      await tester.tap(find.widgetWithText(TextButton, 'auth_sign_up'));
      await tester.pumpAndSettle();

      expect(passwordField(tester).autofillHints, [AutofillHints.newPassword]);
    });
  });
}

/// How many of the step bars are painted in the accent colour.
///
/// The label itself is untranslated under `flutter test`, so the rendered step
/// number is only observable through the bars.
int filledStepBars(WidgetTester tester) {
  final primary = Theme.of(
    tester.element(find.byType(AutofillGroup)),
  ).colorScheme.primary;
  return tester
      .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
      .where((bar) => bar.constraints?.maxHeight == 4)
      .where((bar) => (bar.decoration as BoxDecoration?)?.color == primary)
      .length;
}

TextField emailField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first);

TextField passwordField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).at(1));

InputDecoration passwordDecoration(WidgetTester tester) =>
    passwordField(tester).decoration!;
