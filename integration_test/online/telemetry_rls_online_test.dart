import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/online_test_bootstrap.dart';
import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Online telemetry RLS policy', () {
    testWidgets('anon insert is constrained by telemetry_insert policy', (
      tester,
    ) async {
      final ready = await runOnlineTestApp(skipOnboarding: true);
      ensureBootstrapReady(ready, reason: lastOnlineBootstrapFailureReason);
      await pumpAndSettleWithTimeout(tester);

      final client = Supabase.instance.client;

      await stage('accept valid telemetry payload', () async {
        final now = DateTime.now().toUtc();
        await client.from('telemetry').insert({
          'event': 'integration.telemetry_rls_ok',
          'timestamp': now.toIso8601String(),
          'data': {
            'suite': 'online',
            'case': 'valid_insert',
            'ts': now.millisecondsSinceEpoch,
          },
        });
      });

      await stage('reject invalid event pattern', () async {
        await expectLater(
          () => client.from('telemetry').insert({
            'event': 'Invalid Event Name',
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'data': {'suite': 'online'},
          }),
          throwsA(isA<PostgrestException>()),
        );
      });

      await stage('reject stale timestamp outside policy window', () async {
        await expectLater(
          () => client.from('telemetry').insert({
            'event': 'integration.telemetry_rls_old_ts',
            'timestamp': DateTime.now()
                .toUtc()
                .subtract(const Duration(days: 2))
                .toIso8601String(),
            'data': {'suite': 'online'},
          }),
          throwsA(isA<PostgrestException>()),
        );
      });

      await stage('reject non-object json payload', () async {
        await expectLater(
          () => client.from('telemetry').insert({
            'event': 'integration.telemetry_rls_bad_data',
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'data': ['not', 'an', 'object'],
          }),
          throwsA(isA<PostgrestException>()),
        );
      });
    });
  });
}
