import 'package:go_router/go_router.dart';
import '../../../core/navigation/route_paths.dart';
import 'pages/home_page.dart';
import 'pages/archived_groups_page.dart';

List<RouteBase> getHomeRoutes() {
  return [
    GoRoute(
      path: RoutePaths.home,
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: RoutePaths.archivedGroups,
      builder: (context, state) => const ArchivedGroupsPage(),
    ),
  ];
}
