import 'package:go_router/go_router.dart';
import '../../../core/navigation/app_page.dart';
import '../../../core/navigation/route_paths.dart';
import 'pages/home_page.dart';
import 'pages/archived_groups_page.dart';

/// Maps `/home/:mode` path segment → `home_list_display` setting value.
String? homeListDisplayFromMode(String mode) {
  switch (mode) {
    case 'separate':
      return 'list_separate';
    case 'combined':
      return 'list_combined';
    default:
      return null;
  }
}

/// Maps a full path like `/home/combined` → display setting, or null.
String? homeListDisplayFromPath(String path) {
  if (!path.startsWith('${RoutePaths.homeModeBase}/')) return null;
  if (path.endsWith('/combined')) return 'list_combined';
  if (path.endsWith('/separate')) return 'list_separate';
  return null;
}

List<RouteBase> getHomeRoutes() {
  return [
    GoRoute(
      path: RoutePaths.home,
      pageBuilder: (context, state) => appNoTransitionPage(
        key: state.pageKey,
        child: const HomePage(),
      ),
    ),
    GoRoute(
      path: '${RoutePaths.homeModeBase}/:mode',
      redirect: (context, state) {
        final mode = state.pathParameters['mode'] ?? '';
        if (homeListDisplayFromMode(mode) == null) {
          return RoutePaths.home;
        }
        return null;
      },
      pageBuilder: (context, state) {
        final mode = state.pathParameters['mode'] ?? '';
        return appNoTransitionPage(
          key: state.pageKey,
          child: HomePage(routeDisplayMode: homeListDisplayFromMode(mode)),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.archivedGroups,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const ArchivedGroupsPage(),
      ),
    ),
  ];
}
