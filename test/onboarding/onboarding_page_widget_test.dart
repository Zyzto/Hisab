import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hisab/features/onboarding/pages/onboarding_page.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpOnboardingPage(
    WidgetTester tester, {
    bool forceBusyForTest = false,
  }) async {
    final settings = await initializeHisabSettings();
    if (settings == null) {
      throw Exception('initializeHisabSettings returned null');
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hisabSettingsProvidersProvider.overrideWithValue(settings)],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: MaterialApp(
            home: OnboardingPage(forceBusyForTest: forceBusyForTest),
          ),
        ),
      ),
    );
  }

  testWidgets('OnboardingPage shows first page content and Next button', (
    tester,
  ) async {
    await pumpOnboardingPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });

  testWidgets('OnboardingPage shows first page in Arabic', (tester) async {
    final settings = await initializeHisabSettings();
    if (settings == null) {
      throw Exception('initializeHisabSettings returned null');
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hisabSettingsProvidersProvider.overrideWithValue(settings)],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('ar'),
          child: const MaterialApp(home: OnboardingPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });

  testWidgets('OnboardingPage supports deep-linked initial step', (tester) async {
    final settings = await initializeHisabSettings();
    if (settings == null) {
      throw Exception('initializeHisabSettings returned null');
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hisabSettingsProvidersProvider.overrideWithValue(settings)],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(home: OnboardingPage(initialPage: 2)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets(
    'OnboardingPage disables next action while completion lock is active',
    (tester) async {
      await pumpOnboardingPage(tester, forceBusyForTest: true);
      // Onboarding owns periodic demo timers, so pumpAndSettle can hang forever.
      // A bounded pair of pumps is enough to build the first frame deterministically.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final nextIconFinder = find.byIcon(Icons.arrow_forward);
      expect(nextIconFinder, findsOneWidget);
      final welcomeFinder = find.text('onboarding_welcome'.tr());
      expect(welcomeFinder, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // When completion lock is active, navigation should not advance.
      await tester.tap(nextIconFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(welcomeFinder, findsOneWidget);
    },
  );
}
