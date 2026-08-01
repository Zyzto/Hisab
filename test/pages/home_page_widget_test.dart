// ignore_for_file: prefer_const_constructors

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab/core/widgets/app_fab.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/home/pages/home_page.dart';
import 'package:hisab/features/home/providers/home_list_provider.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  setUp(() {
    // Ambient plant blooms use Timers; keep off so pumpAndSettle can finish.
    AppFab.enableAmbientNature = false;
  });

  testWidgets('HomePage shows app bar and empty list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderedGroupsForHomeProvider.overrideWith(
            (ref) => AsyncValue.data(const []),
          ),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(home: Scaffold(body: HomePage())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byIcon(Icons.add), findsWidgets);
  });

  testWidgets('HomePage empty state shows no_groups and add_first_group', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderedGroupsForHomeProvider.overrideWith(
            (ref) => AsyncValue.data(const []),
          ),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(home: Scaffold(body: HomePage())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byIcon(Icons.group_outlined), findsOneWidget);
  });

  testWidgets('HomePage with one group shows group in list (list default)', (
    tester,
  ) async {
    final now = DateTime(2025, 1, 1);
    final group = Group(
      id: 'g1',
      name: 'Trip',
      currencyCode: 'USD',
      createdAt: now,
      updatedAt: now,
      isPersonal: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderedGroupsForHomeProvider.overrideWith(
            (ref) => AsyncValue.data([group]),
          ),
          homeListDisplayProvider.overrideWithValue('list_separate'),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(home: Scaffold(body: HomePage())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
  });

  testWidgets(
    'HomePage list layout follows homeListDisplayProvider (setting SoT)',
    (tester) async {
      final now = DateTime(2025, 1, 1);
      final personal = Group(
        id: 'p1',
        name: 'Personal',
        currencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
        isPersonal: true,
      );
      final shared = Group(
        id: 'g1',
        name: 'Trip',
        currencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
        isPersonal: false,
      );

      Future<void> pumpWithDisplay(String display) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              orderedGroupsForHomeProvider.overrideWith(
                (ref) => AsyncValue.data([personal, shared]),
              ),
              homeListDisplayProvider.overrideWithValue(display),
              homeListSortProvider.overrideWithValue('updated_at'),
            ],
            child: EasyLocalization(
              path: 'assets/translations',
              supportedLocales: const [Locale('en')],
              fallbackLocale: const Locale('en'),
              startLocale: const Locale('en'),
              child: const MaterialApp(home: Scaffold(body: HomePage())),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpWithDisplay('list_separate');
      expect(
        find.byKey(const PageStorageKey<String>('home_list_separate')),
        findsOneWidget,
      );
      expect(
        find.byKey(const PageStorageKey<String>('home_list_combined')),
        findsNothing,
      );

      await pumpWithDisplay('list_combined');
      expect(
        find.byKey(const PageStorageKey<String>('home_list_combined')),
        findsOneWidget,
      );
      expect(
        find.byKey(const PageStorageKey<String>('home_list_separate')),
        findsNothing,
      );
    },
  );
}
