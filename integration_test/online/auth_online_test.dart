import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/online_test_bootstrap.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Online auth flow', () {
    testWidgets('sign-in → verify session → sign-out → sign-in again', (
      tester,
    ) async {
      final ready = await runOnlineTestApp(
        skipOnboarding: true,
        signInEmail: testUserAEmail,
        signInPassword: testPassword,
      );
      ensureBootstrapReady(ready);
      await pumpAndSettleWithTimeout(tester);

      // ── Stage: verify signed-in state ──
      await stage('verify signed-in state', () async {
        await waitForWidget(
          tester,
          find.text('Groups'),
          timeout: const Duration(seconds: 20),
        );
        // UI-based check: signed-in shell shows Settings in nav (not shown on login screen)
        await waitForWidget(
          tester,
          find.text('Settings'),
          timeout: const Duration(seconds: 10),
        );

        final client = Supabase.instance.client;
        expect(
          client.auth.currentUser,
          isNotNull,
          reason: 'User A should be signed in',
        );
        expect(client.auth.currentUser!.email, equals(testUserAEmail));
      });

      // ── Stage: open Profile (account UI + AppBar logout live there) ──
      await stage('navigate to profile', () async {
        await tapAndSettle(tester, find.text('Settings'));
        await waitForWidget(tester, find.text('Account'));
        // Settings Account section links to Profile; logout is an AppBar action.
        await scrollUntilVisible(tester, find.text('Profile'));
        await tapAndSettle(tester, find.text('Profile').first);
        await waitForWidget(
          tester,
          find.byIcon(Icons.logout),
          timeout: const Duration(seconds: 15),
        );
      });

      // ── Stage: sign out from profile ──
      await stage('sign out', () async {
        await tapAndSettle(tester, find.byIcon(Icons.logout));
        await pumpAndSettleWithTimeout(tester);

        // Confirm sign-out in the confirmation sheet (label is still "Sign out").
        await tester.pump(const Duration(seconds: 1));
        await waitForCondition(
          tester,
          condition: () =>
              isResponsiveSheetVisible() ||
              find.text('Sign out').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
          reason: 'Sign-out confirmation sheet should appear',
        );
        final confirmButton = find.text('Sign out');
        expect(
          confirmButton,
          findsWidgets,
          reason: 'Sign out confirm action should be visible',
        );
        await tapAndSettle(tester, confirmButton.last);
        await pumpAndSettleWithTimeout(tester);
        await waitForResponsiveSheetClosed(tester);

        await tester.pump(const Duration(seconds: 2));

        final client = Supabase.instance.client;
        expect(
          client.auth.currentSession,
          isNull,
          reason: 'Session should be null after sign-out',
        );
      });

      // ── Stage: sign back in programmatically ──
      await stage('sign back in', () async {
        final ok = await signInAs(testUserAEmail, testPassword);
        expect(ok, isTrue, reason: 'Should sign in with User A credentials');

        await tester.pump(const Duration(seconds: 2));
        await pumpAndSettleWithTimeout(tester);

        final client = Supabase.instance.client;
        expect(client.auth.currentUser, isNotNull);
        expect(client.auth.currentUser!.email, equals(testUserAEmail));
      });

      // Leave a clean session for the next testWidgets boot (web release flake).
      await signOutCurrentUser();
    });

    testWidgets('sign-in with User B works', (tester) async {
      final ready = await runOnlineTestApp(
        skipOnboarding: true,
        signInEmail: testUserBEmail,
        signInPassword: testPassword,
      );
      ensureBootstrapReady(ready);
      await pumpAndSettleWithTimeout(tester);

      await stage('verify User B signed in', () async {
        await waitForWidget(
          tester,
          find.text('Groups'),
          timeout: const Duration(seconds: 20),
        );
        // UI-based check: signed-in shell shows Settings in nav (not shown on login screen)
        await waitForWidget(
          tester,
          find.text('Settings'),
          timeout: const Duration(seconds: 10),
        );

        final client = Supabase.instance.client;
        expect(client.auth.currentUser, isNotNull);
        expect(client.auth.currentUser!.email, equals(testUserBEmail));
      });

      await signOutCurrentUser();
    });
  });
}
