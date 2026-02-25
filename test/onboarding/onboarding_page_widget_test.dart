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

  Future<void> pumpOnboardingPage(WidgetTester tester) async {
    final settings = await initializeHisabSettings();
    if (settings == null) {
      throw Exception('initializeHisabSettings returned null');
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hisabSettingsProvidersProvider.overrideWithValue(settings),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: OnboardingPage(),
          ),
        ),
      ),
    );
  }

  testWidgets('OnboardingPage shows first page content and Next button', (tester) async {
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
        overrides: [
          hisabSettingsProvidersProvider.overrideWithValue(settings),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('ar'),
          child: const MaterialApp(
            home: OnboardingPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });
}
