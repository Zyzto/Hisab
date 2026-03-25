// Barrel file: imports all online integration test modules.
//
// Requires a running local Supabase instance (supabase start) and
// --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
//
// Run via:
//   ./scripts/run_online_tests.sh
// Or manually:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/online_app_test.dart -d web-server --release \
//     --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
//     --dart-define=SUPABASE_ANON_KEY=<anon-key>

import 'package:integration_test/integration_test.dart';

import 'online/auth_online_test.dart' as auth_online;
import 'online/sync_online_test.dart' as sync_online;
import 'online/invite_online_test.dart' as invite_online;
import 'online/telemetry_rls_online_test.dart' as telemetry_rls_online;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  auth_online.main();
  sync_online.main();
  invite_online.main();
  telemetry_rls_online.main();
}
