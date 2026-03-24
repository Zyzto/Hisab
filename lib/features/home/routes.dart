import 'package:go_router/go_router.dart';
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
      builder: (context, state) => const HomePage(),
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
      builder: (context, state) {
        final mode = state.pathParameters['mode'] ?? '';
        return HomePage(routeDisplayMode: _displayModeFromPath(mode));
      },
    ),
    GoRoute(
      path: RoutePaths.archivedGroups,
      builder: (context, state) => const ArchivedGroupsPage(),
    ),
  ];
}
