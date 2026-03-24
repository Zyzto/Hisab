import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/groups/pages/group_analytics_page.dart';
import 'package:hisab/features/groups/pages/group_detail_page.dart';
import 'package:hisab/features/groups/providers/group_member_provider.dart';
import 'package:hisab/features/groups/providers/groups_provider.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('group detail analytics button navigates to analytics page', (
    tester,
  ) async {
    const groupId = 'g1';
    final now = DateTime(2026, 1, 1);
    final group = Group(
      id: groupId,
      name: 'Trip',
      currencyCode: 'USD',
      createdAt: now,
      updatedAt: now,
    );
    final participants = [
      Participant(
        id: 'p1',
        groupId: groupId,
        name: 'Ali',
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final router = GoRouter(
      initialLocation: '/groups/$groupId',
      routes: [
        GoRoute(
          path: '/groups/:id',
          builder: (context, state) {
            return GroupDetailPage(groupId: state.pathParameters['id']!);
          },
        ),
        GoRoute(
          path: '/groups/:id/analytics',
          builder: (context, state) {
            return GroupAnalyticsPage(groupId: state.pathParameters['id']!);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveLocalOnlyProvider.overrideWith((ref) => true),
          futureGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(group)),
          expensesByGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data(<Expense>[])),
          participantsByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(participants)),
          tagsByGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data(<ExpenseTag>[])),
          myMemberInGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data(null)),
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

    expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.analytics_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(GroupAnalyticsPage), findsOneWidget);
  });

  testWidgets('analytics trend card switches chart mode from top-right menu', (
    tester,
  ) async {
    const groupId = 'g2';
    final now = DateTime(2026, 3, 20);
    final group = Group(
      id: groupId,
      name: 'Trip',
      currencyCode: 'USD',
      createdAt: now,
      updatedAt: now,
    );
    final participants = [
      Participant(
        id: 'p1',
        groupId: groupId,
        name: 'Ali',
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
      Participant(
        id: 'p2',
        groupId: groupId,
        name: 'Sara',
        order: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final expenses = [
      Expense(
        id: 'e1',
        groupId: groupId,
        payerParticipantId: 'p1',
        amountCents: 1400,
        currencyCode: 'USD',
        title: 'Coffee',
        date: DateTime(2026, 3, 18),
        splitType: SplitType.equal,
        splitShares: const {},
        createdAt: now,
        updatedAt: now,
        tag: 'coffee',
      ),
      Expense(
        id: 'e2',
        groupId: groupId,
        payerParticipantId: 'p2',
        amountCents: 900,
        currencyCode: 'USD',
        title: 'Taxi',
        date: DateTime(2026, 3, 19),
        splitType: SplitType.equal,
        splitShares: const {},
        createdAt: now,
        updatedAt: now,
        tag: 'transport',
      ),
    ];
    final router = GoRouter(
      initialLocation: '/groups/$groupId/analytics',
      routes: [
        GoRoute(
          path: '/groups/:id',
          builder: (context, state) {
            return GroupDetailPage(groupId: state.pathParameters['id']!);
          },
        ),
        GoRoute(
          path: '/groups/:id/analytics',
          builder: (context, state) {
            return GroupAnalyticsPage(groupId: state.pathParameters['id']!);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveLocalOnlyProvider.overrideWith((ref) => true),
          futureGroupProvider(groupId).overrideWithValue(AsyncValue.data(group)),
          expensesByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(expenses)),
          participantsByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(participants)),
          tagsByGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data(<ExpenseTag>[])),
          myMemberInGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data(null)),
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

    final totalBarLabel = 'analytics_chart_mode_total_bar'.tr();
    final userComparisonLabel = 'analytics_chart_mode_users_line'.tr();
    expect(find.text(totalBarLabel), findsOneWidget);
    await tester.tap(find.text(totalBarLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(userComparisonLabel));
    await tester.pumpAndSettle();

    expect(find.text(userComparisonLabel), findsWidgets);
  });

  testWidgets('category analytics renders with expense data', (
    tester,
  ) async {
    const groupId = 'g3';
    final now = DateTime(2026, 3, 20);
    final group = Group(
      id: groupId,
      name: 'Trip',
      currencyCode: 'USD',
      createdAt: now,
      updatedAt: now,
    );
    final participants = [
      Participant(
        id: 'p1',
        groupId: groupId,
        name: 'Ali',
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
      Participant(
        id: 'p2',
        groupId: groupId,
        name: 'Sara',
        order: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final expenses = [
      Expense(
        id: 'e1',
        groupId: groupId,
        payerParticipantId: 'p1',
        amountCents: 2200,
        currencyCode: 'USD',
        title: 'Groceries',
        date: DateTime(2026, 3, 18),
        splitType: SplitType.equal,
        splitShares: const {},
        createdAt: now,
        updatedAt: now,
        tag: 'groceries',
      ),
      Expense(
        id: 'e2',
        groupId: groupId,
        payerParticipantId: 'p2',
        amountCents: 900,
        currencyCode: 'USD',
        title: 'Taxi',
        date: DateTime(2026, 3, 19),
        splitType: SplitType.equal,
        splitShares: const {},
        createdAt: now,
        updatedAt: now,
        tag: 'transport',
      ),
    ];

    final router = GoRouter(
      initialLocation: '/groups/$groupId/analytics',
      routes: [
        GoRoute(
          path: '/groups/:id',
          builder: (context, state) {
            return GroupDetailPage(groupId: state.pathParameters['id']!);
          },
        ),
        GoRoute(
          path: '/groups/:id/analytics',
          builder: (context, state) {
            return GroupAnalyticsPage(groupId: state.pathParameters['id']!);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveLocalOnlyProvider.overrideWith((ref) => true),
          futureGroupProvider(groupId).overrideWithValue(AsyncValue.data(group)),
          expensesByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(expenses)),
          participantsByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(participants)),
          tagsByGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data(<ExpenseTag>[])),
          myMemberInGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data(null)),
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

    expect(find.byType(GroupAnalyticsPage), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
  });
}
