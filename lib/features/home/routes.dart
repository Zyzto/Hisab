import 'package:go_router/go_router.dart';
import '../../../core/navigation/app_page.dart';
import '../../../core/navigation/route_paths.dart';
import 'pages/home_page.dart';
import 'pages/archived_groups_page.dart';

String? _displayModeFromPath(String mode) {
  switch (mode) {
    case 'separate':
      return 'list_separate';
    case 'combined':
      return 'list_combined';
    default:
      return null;
  }
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
        if (_displayModeFromPath(mode) == null) {
          return RoutePaths.home;
        }
        return null;
      },
      pageBuilder: (context, state) {
        final mode = state.pathParameters['mode'] ?? '';
        return appNoTransitionPage(
          key: state.pageKey,
          child: HomePage(routeDisplayMode: _displayModeFromPath(mode)),
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
