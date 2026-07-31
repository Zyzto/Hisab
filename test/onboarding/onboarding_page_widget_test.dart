import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hisab/core/constants/supabase_config.dart';
import 'package:hisab/features/onboarding/pages/onboarding_page.dart';
import 'package:hisab/features/onboarding/widgets/onboarding_welcome_page.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';
import 'package:hisab/features/settings/settings_definitions.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
    SharedPreferences.setMockInitialValues({});
  });

  /// Onboarding owns periodic demo timers and welcome stagger controllers, so
  /// [WidgetTester.pumpAndSettle] can hang forever. Bounded pumps are enough.
  Future<void> pumpOnboardingFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> advancePage(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    // AppMotion.page is 280ms; allow settle of the PageView animation.
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<SettingsProviders> pumpOnboardingPage(
    WidgetTester tester, {
    bool forceBusyForTest = false,
    int initialPage = 0,
    Locale locale = const Locale('en'),
  }) async {
    // rootBundle / SharedPreferences need real async inside testWidgets.
    final settings = await tester.runAsync(initializeHisabSettings);
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
          startLocale: locale,
          child: MaterialApp(
            home: OnboardingPage(
              forceBusyForTest: forceBusyForTest,
              initialPage: initialPage,
            ),
          ),
        ),
      ),
    );
    await pumpOnboardingFrames(tester);
    return settings;
  }

  group('Welcome', () {
    testWidgets('shows brand welcome, how-it-works, and Next', (tester) async {
      await pumpOnboardingPage(tester);

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(OnboardingWelcomePage), findsOneWidget);
      expect(find.text('onboarding_welcome'.tr()), findsOneWidget);
      expect(find.text('onboarding_how_it_works'.tr()), findsOneWidget);
      expect(find.text('onboarding_groups'.tr()), findsOneWidget);
      expect(find.text('onboarding_personal'.tr()), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('shows language and theme demo controls', (tester) async {
      await pumpOnboardingPage(tester);

      expect(find.byIcon(Icons.language), findsOneWidget);
      // Theme button cycles; at least one of the common demo icons is present.
      final hasThemeIcon = find.byIcon(Icons.light_mode).evaluate().isNotEmpty ||
          find.byIcon(Icons.dark_mode).evaluate().isNotEmpty ||
          find.byIcon(Icons.motion_photos_auto).evaluate().isNotEmpty ||
          find.byIcon(Icons.brightness_auto).evaluate().isNotEmpty ||
          find.byIcon(Icons.contrast).evaluate().isNotEmpty;
      expect(hasThemeIcon, isTrue);
    });

    testWidgets('renders Arabic welcome copy', (tester) async {
      await pumpOnboardingPage(tester, locale: const Locale('ar'));

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('onboarding_welcome'.tr()), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });
  });

  group('Navigation', () {
    testWidgets('Next advances Welcome → Preferences', (tester) async {
      await pumpOnboardingPage(tester);

      await advancePage(tester);

      expect(find.text('onboarding_preferences'.tr()).hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('Next advances through all steps to Start', (tester) async {
      await pumpOnboardingPage(tester);

      await advancePage(tester); // Preferences
      expect(find.text('onboarding_preferences'.tr()).hitTestable(), findsOneWidget);

      await advancePage(tester); // Permissions
      expect(
        find.text('onboarding_permissions_title'.tr()).hitTestable(),
        findsOneWidget,
      );

      await advancePage(tester); // Connect
      expect(find.text('onboarding_connect'.tr()).hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
      expect(find.text('onboarding_complete'.tr()), findsOneWidget);
    });

    testWidgets('Back from Preferences returns to Welcome', (tester) async {
      await pumpOnboardingPage(tester);
      await advancePage(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('onboarding_welcome'.tr()).hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });

  group('Deep links', () {
    testWidgets('initialPage Preferences shows Back + prefs title', (tester) async {
      await pumpOnboardingPage(tester, initialPage: 1);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('onboarding_preferences'.tr()).hitTestable(), findsOneWidget);
    });

    testWidgets('initialPage Permissions shows permissions title', (tester) async {
      await pumpOnboardingPage(tester, initialPage: 2);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(
        find.text('onboarding_permissions_title'.tr()).hitTestable(),
        findsOneWidget,
      );
      // Telemetry toggle is always on this step.
      expect(find.text('telemetry_enabled'.tr()), findsOneWidget);
    });

    testWidgets('initialPage Connect shows mode UI for config', (tester) async {
      await pumpOnboardingPage(tester, initialPage: 3);

      expect(find.text('onboarding_connect'.tr()).hitTestable(), findsOneWidget);
      expect(find.text('onboarding_complete'.tr()), findsOneWidget);
      // Privacy CTA is Text.rich — match the linked label in the plain text.
      expect(find.textContaining('privacy_policy'.tr()), findsOneWidget);

      if (supabaseConfigAvailable) {
        expect(find.text('onboarding_offline'.tr()), findsOneWidget);
        expect(find.text('onboarding_online'.tr()), findsOneWidget);
        expect(find.text('onboarding_offline_desc'.tr()), findsWidgets);
      } else {
        expect(find.text('onboarding_online_unavailable'.tr()), findsOneWidget);
        expect(find.text('onboarding_offline_desc'.tr()), findsOneWidget);
      }
    });
  });

  group('Connect mode', () {
    ProviderContainer containerOf(WidgetTester tester) {
      return ProviderScope.containerOf(tester.element(find.byType(OnboardingPage)));
    }

    testWidgets(
      'selecting Online updates page subtitle when cloud is configured',
      (tester) async {
        final settings = await pumpOnboardingPage(tester, initialPage: 3);
        expect(find.text('onboarding_online'.tr()), findsOneWidget);

        await tester.tap(find.text('onboarding_online'.tr()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('onboarding_online_desc'.tr()), findsWidgets);
        expect(
          containerOf(tester).read(settings.provider(localOnlySettingDef)),
          isFalse,
        );
      },
      skip: !supabaseConfigAvailable,
    );

    testWidgets(
      'offline remains default when cloud is unavailable',
      (tester) async {
        final settings = await pumpOnboardingPage(tester, initialPage: 3);
        expect(
          containerOf(tester).read(settings.provider(localOnlySettingDef)),
          isTrue,
        );
        expect(find.text('onboarding_online_unavailable'.tr()), findsOneWidget);
      },
      skip: supabaseConfigAvailable,
    );
  });

  group('Completion lock', () {
    testWidgets('disables Next and shows busy overlay', (tester) async {
      await pumpOnboardingPage(tester, forceBusyForTest: true);

      final nextIconFinder = find.byIcon(Icons.arrow_forward);
      expect(nextIconFinder, findsOneWidget);
      final welcomeFinder = find.text('onboarding_welcome'.tr());
      expect(welcomeFinder, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(nextIconFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(welcomeFinder, findsOneWidget);
    });
  });
}
