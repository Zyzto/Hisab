import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab/features/expenses/pages/expense_detail_shell.dart';
import 'package:hisab/features/groups/pages/group_detail_page.dart';

import 'package:hisab/features/groups/pages/invite_group_preview_page.dart';
import 'package:hisab/features/groups/providers/invite_preview_provider.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('shows three tabs and no mutating actions', (tester) async {
    final dataByRpc = <String, dynamic>{
      'get_invite_preview_group': [
        {
          'invite_id': 'invite-1',
          'invite_access_mode': 'readonly_only',
          'group_id': 'group-1',
          'group_name': 'Preview Group',
          'group_currency_code': 'USD',
          'group_settlement_method': 'greedy',
          'group_treasurer_participant_id': null,
          'group_allow_member_settle_for_others': false,
          'group_created_at': '2026-01-01T00:00:00Z',
          'group_updated_at': '2026-01-01T00:00:00Z',
        },
      ],
      'get_invite_preview_participants': [
        {
          'id': 'p1',
          'group_id': 'group-1',
          'name': 'A',
          'sort_order': 0,
          'user_id': null,
          'avatar_id': null,
          'left_at': null,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
          'member_role': 'member',
        },
      ],
      'get_invite_preview_expenses': <Map<String, dynamic>>[],
    };

    final router = GoRouter(
      initialLocation: '/invite/token-1/preview/expenses',
      routes: [
        GoRoute(
          path: '/invite/:token/preview',
          redirect: (context, state) {
            final token = state.pathParameters['token']!;
            return '/invite/$token/preview/expenses';
          },
        ),
        GoRoute(
          path: '/invite/:token/preview/expenses',
          builder: (context, state) => InviteGroupPreviewPage(
            token: state.pathParameters['token']!,
          ),
        ),
        GoRoute(
          path: '/invite/:token/preview/balance',
          builder: (context, state) => InviteGroupPreviewPage(
            token: state.pathParameters['token']!,
            initialTab: GroupDetailTab.balance,
          ),
        ),
        GoRoute(
          path: '/invite/:token/preview/people',
          builder: (context, state) => InviteGroupPreviewPage(
            token: state.pathParameters['token']!,
            initialTab: GroupDetailTab.people,
          ),
        ),
        GoRoute(
          path: '/invite/:token/preview/expenses/:eid',
          builder: (context, state) => InvitePreviewExpenseDetailPage(
            token: state.pathParameters['token']!,
            expenseId: state.pathParameters['eid']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invitePreviewRpcProvider.overrideWithValue((rpcName, params) async {
            return dataByRpc[rpcName];
          }),
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

    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'Expenses' || w.data == 'expenses'),
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'Balance' || w.data == 'balance'),
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'People' || w.data == 'people'),
      ),
      findsWidgets,
    );

    // Regression: preview balance tab must resolve data and never show
    // "Group not found" due to missing provider overrides.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'Balance' || w.data == 'balance'),
      ).first,
    );
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/invite/token-1/preview/balance',
    );
    expect(find.text('Group not found'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').toLowerCase().contains('settle'),
      ),
      findsWidgets,
    );

    expect(find.byIcon(Icons.settings), findsNothing);
    expect(find.byIcon(Icons.person_add), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.text('Join this group'), findsNothing);
  });

  testWidgets('opens read-only expense detail and shows image section', (
    tester,
  ) async {
    final dataByRpc = <String, dynamic>{
      'get_invite_preview_group': [
        {
          'invite_id': 'invite-1',
          'invite_access_mode': 'readonly_join',
          'group_id': 'group-1',
          'group_name': 'Preview Group',
          'group_currency_code': 'USD',
          'group_settlement_method': 'greedy',
          'group_treasurer_participant_id': null,
          'group_allow_member_settle_for_others': false,
          'group_created_at': '2026-01-01T00:00:00Z',
          'group_updated_at': '2026-01-01T00:00:00Z',
        },
      ],
      'get_invite_preview_participants': [
        {
          'id': 'p1',
          'group_id': 'group-1',
          'name': 'Owner',
          'sort_order': 0,
          'user_id': null,
          'avatar_id': null,
          'left_at': null,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
          'member_role': 'member',
        },
        {
          'id': 'p2',
          'group_id': 'group-1',
          'name': 'User B',
          'sort_order': 1,
          'user_id': null,
          'avatar_id': null,
          'left_at': null,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
          'member_role': 'member',
        },
      ],
      'get_invite_preview_expenses': [
        {
          'id': 'e1',
          'group_id': 'group-1',
          'payer_participant_id': 'p1',
          'amount_cents': 1000,
          'currency_code': 'USD',
          'exchange_rate': 1.0,
          'base_amount_cents': 1000,
          'title': 'Dinner',
          'date': '2026-01-02T00:00:00Z',
          'split_type': 'equal',
          'split_shares_json': '{"p1":500,"p2":500}',
          'type': 'expense',
          'to_participant_id': null,
          'image_path': '/tmp/fake-image.jpg',
          'image_paths': '["/tmp/fake-image.jpg"]',
          'created_at': '2026-01-02T00:00:00Z',
          'updated_at': '2026-01-02T00:00:00Z',
        },
      ],
    };

    final router = GoRouter(
      initialLocation: '/invite/token-1/preview/expenses',
      routes: [
        GoRoute(
          path: '/invite/:token/preview',
          redirect: (context, state) {
            final token = state.pathParameters['token']!;
            return '/invite/$token/preview/expenses';
          },
        ),
        GoRoute(
          path: '/invite/:token/preview/expenses',
          builder: (context, state) => InviteGroupPreviewPage(
            token: state.pathParameters['token']!,
          ),
        ),
        GoRoute(
          path: '/invite/:token/preview/expenses/:eid',
          builder: (context, state) => InvitePreviewExpenseDetailPage(
            token: state.pathParameters['token']!,
            expenseId: state.pathParameters['eid']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invitePreviewRpcProvider.overrideWithValue((rpcName, params) async {
            return dataByRpc[rpcName];
          }),
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

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            ((w.data ?? '').toLowerCase().contains('join') ||
                (w.data ?? '').toLowerCase().contains('invite_preview_join_cta')),
      ),
      findsWidgets,
    );
    await tester.tap(find.text('Dinner').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ExpenseDetailShell), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsNothing);
    expect(find.byIcon(Icons.person_add), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
  });
}
