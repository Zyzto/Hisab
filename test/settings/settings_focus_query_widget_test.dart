import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_settings_framework/safaeh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab/core/navigation/route_paths.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';
import 'package:hisab/core/settings/settings_definitions.dart';
import 'package:hisab/features/settings/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'focus query expands appearance and highlights display currency',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = await tester.runAsync(initializeHisabSettings);
      if (settings == null) {
        throw Exception('initializeHisabSettings returned null');
      }

      final router = GoRouter(
        initialLocation: RoutePaths.settingsFocus(
          displayCurrencySettingDef.key,
        ),
        routes: [
          GoRoute(
            path: RoutePaths.settings,
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      );

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
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('display_currency'.tr()), findsOneWidget);
      expect(router.state.uri.path, RoutePaths.settings);
      expect(router.state.uri.queryParameters, isEmpty);
    },
  );

  testWidgets('settings search starts collapsed and opens as an overlay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = await tester.runAsync(initializeHisabSettings);
    if (settings == null) {
      throw Exception('initializeHisabSettings returned null');
    }

    final router = GoRouter(
      initialLocation: RoutePaths.settings,
      routes: [
        GoRoute(
          path: RoutePaths.settings,
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hisabSettingsProvidersProvider.overrideWithValue(settings),
          settingsSearchIndexProvider.overrideWithValue(settings.searchIndex),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overlay = tester.widget<SafaehSettingsSearchOverlay>(
      find.byType(SafaehSettingsSearchOverlay),
    );
    expect(overlay.isOpen, isFalse);

    await tester.tap(
      find.byKey(const ValueKey('safaeh_settings_search_button')),
    );
    await tester.pump(const Duration(milliseconds: 350));

    final expandedOverlay = tester.widget<SafaehSettingsSearchOverlay>(
      find.byType(SafaehSettingsSearchOverlay),
    );
    expect(expandedOverlay.isOpen, isTrue);
    expect(
      find.byKey(const ValueKey('safaeh_settings_search_field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('safaeh_settings_search_field')),
      'language',
    );
    await tester.pump(const Duration(milliseconds: 350));
    final searchOverlay = find.byType(SafaehSettingsSearchOverlay);
    expect(
      find.descendant(
        of: searchOverlay,
        matching: find.text('appearance'.tr()),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('›'), findsNothing);
    expect(
      find.descendant(
        of: searchOverlay,
        matching: find.byKey(const ValueKey('safaeh_settings_search_clear')),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('safaeh_settings_search_scrim')),
    );
    await tester.pump(const Duration(milliseconds: 350));
    final collapsedOverlay = tester.widget<SafaehSettingsSearchOverlay>(
      find.byType(SafaehSettingsSearchOverlay),
    );
    expect(collapsedOverlay.isOpen, isFalse);
  });
}
