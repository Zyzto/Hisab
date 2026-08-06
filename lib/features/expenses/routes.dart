import 'package:go_router/go_router.dart';
import '../../core/navigation/app_page.dart';
import '../groups/pages/group_detail_page.dart';
import 'pages/expense_detail_shell.dart';
import 'pages/expense_form_page.dart';
import 'widgets/expense_detail_body.dart';

List<RouteBase> getExpenseRoutes() {
  return [
    GoRoute(
      path: '/groups/:id/expenses/add',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['id'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: ExpenseFormPage(groupId: groupId),
        );
      },
    ),
    GoRoute(
      path: '/groups/:id/expenses',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['id'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: GroupDetailPage(
            groupId: groupId,
            initialTab: GroupDetailTab.expenses,
          ),
        );
      },
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            final groupId = state.pathParameters['id'] ?? '';
            final pathSegments = state.uri.pathSegments;
            final expenseId =
                state.pathParameters['eid'] ??
                (pathSegments.length >= 4 ? pathSegments[3] : '');
            return ExpenseDetailShell(
              groupId: groupId,
              expenseId: expenseId,
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: ':eid',
              pageBuilder: (context, state) {
                final groupId = state.pathParameters['id'] ?? '';
                final expenseId = state.pathParameters['eid'] ?? '';
                return appNoTransitionPage(
                  key: state.pageKey,
                  child: ExpenseDetailBody(
                    groupId: groupId,
                    expenseId: expenseId,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/groups/:id/expenses/:eid/edit',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['id'] ?? '';
        final expenseId = state.pathParameters['eid'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: ExpenseFormPage(groupId: groupId, expenseId: expenseId),
        );
      },
    ),
  ];
}
