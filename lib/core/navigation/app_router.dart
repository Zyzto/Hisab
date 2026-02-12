import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:go_router/go_router.dart';
import 'route_paths.dart';
import '../../features/home/routes.dart';
import '../../features/settings/routes.dart';
import '../../features/settings/providers/settings_framework_providers.dart';
import '../../features/groups/pages/group_create_page.dart';
import '../../features/groups/pages/group_detail_page.dart';
import '../../features/groups/pages/group_settings_page.dart';
import '../../features/expenses/pages/expense_form_page.dart';
import '../../features/expenses/pages/expense_detail_page.dart';
import 'main_scaffold.dart';

part 'app_router.g.dart';

/// Notifier that triggers GoRouter refresh when locale changes.
/// Ensures navigation labels and all visible content update in realtime.
@riverpod
ValueNotifier<String> localeRefreshNotifier(Ref ref) {
  final notifier = ValueNotifier<String>(ref.read(languageProvider));
  ref.listen(languageProvider, (_, next) => notifier.value = next);
  return notifier;
}

@riverpod
GoRouter router(Ref ref) {
  final refreshNotifier = ref.watch(localeRefreshProvider);
  return GoRouter(
    refreshListenable: refreshNotifier,
    initialLocation: RoutePaths.home,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          final location = state.uri.path;
          int selectedIndex = 0;
          if (location.startsWith(RoutePaths.settings)) {
            selectedIndex = 1;
          }
          return MainScaffold(
            selectedIndex: selectedIndex,
            location: location,
            child: child,
          );
        },
        routes: [...getHomeRoutes(), ...getSettingsRoutes()],
      ),
      GoRoute(
        path: '/groups/create',
        builder: (context, state) => const GroupCreatePage(),
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return GroupDetailPage(groupId: id);
        },
      ),
      GoRoute(
        path: '/groups/:id/settings',
        builder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          return GroupSettingsPage(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/groups/:id/expenses/add',
        builder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          return ExpenseFormPage(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/groups/:id/expenses/:eid',
        builder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          final expenseId = state.pathParameters['eid'] ?? '';
          return ExpenseDetailPage(groupId: groupId, expenseId: expenseId);
        },
      ),
      GoRoute(
        path: '/groups/:id/expenses/:eid/edit',
        builder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          final expenseId = state.pathParameters['eid'] ?? '';
          return ExpenseFormPage(groupId: groupId, expenseId: expenseId);
        },
      ),
    ],
  );
}
