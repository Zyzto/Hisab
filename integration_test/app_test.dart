// Barrel file: imports all integration test modules.
// Run everything via:
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d web-server --release
// Or on Android:
//   flutter test integration_test/app_test.dart -d <device_id>
//
// Debugging: When a test fails, check the console for "[integration stage]" lines.
// The last "STARTED" or "PASSED" stage before the failure shows where the test reached.
// Failures inside stage() also report: FAILED at stage "stage name": <error>.

import 'smoke_test.dart' as smoke;
import 'onboarding_test.dart' as onboarding;
import 'group_flows_test.dart' as group_flows;
import 'personal_test.dart' as personal;
import 'expense_flows_test.dart' as expense_flows;
import 'balance_test.dart' as balance;
import 'settings_test.dart' as settings;
import 'display_currency_test.dart' as display_currency;

void main() {
  smoke.main();
  onboarding.main();
  group_flows.main();
  personal.main();
  expense_flows.main();
  balance.main();
  settings.main();
  display_currency.main();
}
