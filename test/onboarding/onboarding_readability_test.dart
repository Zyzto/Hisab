import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hisab/features/onboarding/pages/onboarding_page.dart';
import 'package:hisab/features/onboarding/widgets/onboarding_shared.dart';
import 'package:hisab/features/onboarding/widgets/onboarding_welcome_page.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpStep(WidgetTester tester, int page) async {
    final settings = await tester.runAsync(initializeHisabSettings);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hisabSettingsProvidersProvider.overrideWithValue(settings!),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: MaterialApp(home: OnboardingPage(initialPage: page)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 350));
  }

  test('translucent fills are flattened so the meadow cannot bleed through', () {
    const scheme = ColorScheme.light();
    final flattened = onboardingOpaqueFill(
      scheme,
      scheme.primaryContainer.withValues(alpha: 0.35),
    );
    expect(flattened.a, 1.0);
    expect(flattened, isNot(scheme.primaryContainer.withValues(alpha: 0.35)));
  });

  test('sky ink flips with the meadow: white at night, deep at day', () {
    expect(
      onboardingSkyInkForBrightness(Brightness.dark),
      Colors.white.withValues(alpha: 0.94),
    );
    expect(
      onboardingSkyInkForBrightness(Brightness.light),
      const Color(0xFF0E1A14).withValues(alpha: 0.94),
    );
  });

  testWidgets('titles sit bare on the sky — no plaque card', (tester) async {
    const titleKeys = [
      'onboarding_welcome',
      'onboarding_preferences',
      'onboarding_permissions_title',
      'onboarding_connect',
    ];
    for (var page = 0; page < titleKeys.length; page++) {
      await pumpStep(tester, page);
      expect(
        find.ancestor(
          of: find.text(titleKeys[page].tr()),
          matching: find.byType(OnboardingPlaque),
        ),
        findsNothing,
        reason: 'step $page title must not sit in a card',
      );
      expect(find.byType(OnboardingTitleBlock), findsOneWidget);
    }
  });

  testWidgets('welcome section label is bare sky text too', (tester) async {
    await pumpStep(tester, 0);
    expect(
      find.ancestor(
        of: find.text('onboarding_how_it_works'.tr()),
        matching: find.byType(OnboardingSectionLabel),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('onboarding_how_it_works'.tr()),
        matching: find.byType(OnboardingPlaque),
      ),
      findsNothing,
    );
  });

  testWidgets('hero card renders the app mark at hero size', (tester) async {
    await pumpStep(tester, 0);
    final logo = tester.widgetList<Image>(find.byType(Image)).firstWhere(
          (image) => image.width == OnboardingWelcomePage.heroLogoSize,
          orElse: () => throw StateError('no hero-sized logo found'),
        );
    expect(logo.height, OnboardingWelcomePage.heroLogoSize);
  });

  testWidgets('footer chrome sits on a scrim, not bare grass', (tester) async {
    await pumpStep(tester, 0);
    final scrim = find.ancestor(
      of: find.byIcon(Icons.arrow_forward),
      matching: find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration && decoration.gradient != null;
      }),
    );
    expect(scrim, findsOneWidget);
  });

  testWidgets('footer content inset clears chrome plus home indicator', (
    tester,
  ) async {
    late double inset;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
        child: Builder(
          builder: (context) {
            inset = onboardingFooterContentInset(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(inset, kOnboardingFooterChromeHeight + 34);
  });
}
