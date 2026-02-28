import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/online_test_bootstrap.dart';
import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Online auth flow', () {
    testWidgets('sign-in → verify session → sign-out → sign-in again',
        (tester) async {
      final ready = await runOnlineTestApp(
        skipOnboarding: true,
        signInEmail: testUserAEmail,
        signInPassword: testPassword,
      );
      ensureBootstrapReady(ready);
      await pumpAndSettleWithTimeout(tester);

      // ── Stage: verify signed-in state ──
      await stage('verify signed-in state', () async {
        await waitForWidget(tester, find.text('Groups'),
            timeout: const Duration(seconds: 20));

        final client = Supabase.instance.client;
        expect(client.auth.currentUser, isNotNull,
            reason: 'User A should be signed in');
        expect(client.auth.currentUser!.email, equals(testUserAEmail));
      });

      // ── Stage: navigate to settings ──
      await stage('navigate to settings', () async {
        await tapAndSettle(tester, find.text('Settings'));
        await waitForWidget(tester, find.text('Account'));
      });

      // ── Stage: sign out from settings ──
      await stage('sign out', () async {
        // Account section is expanded by default; scroll to the Sign out tile
        await scrollUntilVisible(tester, find.text('Sign out'));
        await tapAndSettle(tester, find.text('Sign out'));
        await pumpAndSettleWithTimeout(tester);

        // Confirm sign-out in the confirmation dialog
        await tester.pump(const Duration(seconds: 1));
        final confirmButton = find.text('Sign out');
        if (confirmButton.evaluate().isNotEmpty) {
          await tapAndSettle(tester, confirmButton.last);
          await pumpAndSettleWithTimeout(tester);
        }

        await tester.pump(const Duration(seconds: 2));

        final client = Supabase.instance.client;
        expect(client.auth.currentSession, isNull,
            reason: 'Session should be null after sign-out');
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
        await waitForWidget(tester, find.text('Groups'),
            timeout: const Duration(seconds: 20));

        final client = Supabase.instance.client;
        expect(client.auth.currentUser, isNotNull);
        expect(client.auth.currentUser!.email, equals(testUserBEmail));
      });

      await signOutCurrentUser();
    });
  });
}
