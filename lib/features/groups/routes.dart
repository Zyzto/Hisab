import 'package:go_router/go_router.dart';

import '../../core/navigation/app_page.dart';
import '../../core/navigation/route_paths.dart';
import 'pages/group_analytics_page.dart';
import 'pages/group_categories_page.dart';
import 'pages/group_create_page.dart';
import 'pages/group_detail_page.dart';
import 'pages/group_settings_page.dart';

List<RouteBase> getGroupRoutes() {
  return [
    GoRoute(
      path: RoutePaths.groupCreate,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: false),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreatePersonal,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: true),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreateDetails,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: false, initialStep: 0),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreateParticipants,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: false, initialStep: 1),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreateStyle,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: false, initialStep: 2),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreateReview,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: false, initialStep: 3),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreatePersonalDetails,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: true, initialStep: 0),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreatePersonalStyle,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: true, initialStep: 1),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreatePersonalReview,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: true, initialStep: 2),
      ),
    ),
    GoRoute(
      path: '/groups/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return id.isEmpty ? RoutePaths.home : RoutePaths.groupExpenses(id);
      },
    ),
    GoRoute(
      path: '/groups/:id/people',
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: GroupDetailPage(
          groupId: state.pathParameters['id'] ?? '',
          initialTab: GroupDetailTab.people,
        ),
      ),
    ),
    GoRoute(
      path: '/groups/:id/settings',
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: GroupSettingsPage(groupId: state.pathParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/groups/:id/analytics',
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: GroupAnalyticsPage(groupId: state.pathParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/groups/:id/categories',
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: GroupCategoriesPage(groupId: state.pathParameters['id'] ?? ''),
      ),
    ),
  ];
}
