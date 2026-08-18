import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hisab/core/auth/auth_providers.dart';
import 'package:hisab/features/settings/widgets/change_password_sheet.dart';

import '../core/auth/fake_auth_service.dart';
import '../widget_test_helpers.dart';

/// Under `flutter test` easy_localization resolves to the raw key, so finders
/// match key strings rather than English copy.
void main() {
  setUpAll(() => EasyLocalization.logger.enableBuildModes = []);

  late FakeAuthService auth;

  setUp(() => auth = FakeAuthService());
  tearDown(() => auth.close());

  Future<void> openSheet(WidgetTester tester, ChangePasswordMode mode) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (ctx, ref, _) => FilledButton(
                onPressed: () => showChangePasswordSheet(ctx, ref, mode: mode),
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

  testWidgets('recovery mode drops the current-password field', (tester) async {
    await openSheet(tester, ChangePasswordMode.recovery);

    expect(find.text('change_password_recovery_subtitle'), findsOneWidget);
    expect(find.text('change_password_current'), findsNothing);
    expect(find.text('change_password_new'), findsOneWidget);
    expect(find.text('change_password_confirm'), findsOneWidget);
  });

  testWidgets('recovery mode updates without re-authenticating', (
    tester,
  ) async {
    await openSheet(tester, ChangePasswordMode.recovery);

    await tester.enterText(find.byType(TextField).first, 'newsecret');
    await tester.enterText(find.byType(TextField).at(1), 'newsecret');
    await tester.pumpAndSettle();
    await tester.tap(find.text('change_password'));
    await tester.pumpAndSettle();

    // Following the recovery link is the proof of identity, so the old
    // password is never asked for and never checked.
    expect(auth.calls, ['updatePassword']);
    expect(auth.lastNewPassword, 'newsecret');

    // Outlive the success toast's auto-close timer.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('recovery mode still enforces the minimum length', (
    tester,
  ) async {
    await openSheet(tester, ChangePasswordMode.recovery);

    await tester.enterText(find.byType(TextField).first, 'abc');
    await tester.enterText(find.byType(TextField).at(1), 'abc');
    await tester.pumpAndSettle();
    await tester.tap(find.text('change_password'));
    await tester.pumpAndSettle();

    expect(find.text('change_password_too_short'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('recovery mode rejects a mismatch', (tester) async {
    await openSheet(tester, ChangePasswordMode.recovery);

    await tester.enterText(find.byType(TextField).first, 'newsecret');
    await tester.enterText(find.byType(TextField).at(1), 'different');
    await tester.pumpAndSettle();
    await tester.tap(find.text('change_password'));
    await tester.pumpAndSettle();

    expect(find.text('change_password_mismatch'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('normal mode keeps the current-password field', (tester) async {
    await openSheet(tester, ChangePasswordMode.normal);

    expect(find.text('change_password_current'), findsOneWidget);
    expect(find.text('change_password_recovery_subtitle'), findsNothing);
  });
}
