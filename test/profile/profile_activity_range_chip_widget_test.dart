import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hisab/core/widgets/anchored_dropdown_chip.dart';
import 'package:hisab/features/groups/providers/group_analytics_provider.dart';
import 'package:hisab/features/profile/providers/profile_activity_provider.dart';
import 'package:hisab/features/profile/providers/profile_my_expenses_provider.dart';
import 'package:hisab/features/profile/widgets/profile_activity_section.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets(
    'profile activity range uses AnchoredDropdownChip not ChoiceChips',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileAnalyticsRangeProvider.overrideWith(
              (ref) => AnalyticsRangePreset.days30,
            ),
            profileMyExpensesProvider.overrideWith(
              (ref) => const AsyncValue.data(<ProfileExpenseItem>[]),
            ),
            displayCurrencyProvider.overrideWith((ref) => 'USD'),
          ],
          child: EasyLocalization(
            path: 'assets/translations',
            supportedLocales: testSupportedLocales,
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            child: const MaterialApp(
              home: Scaffold(body: ProfileActivitySection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsNothing);
      expect(
        find.byType(AnchoredDropdownChip<AnalyticsRangePreset>),
        findsOneWidget,
      );
      expect(find.text('analytics_range_30d'.tr()), findsOneWidget);
    },
  );
}
