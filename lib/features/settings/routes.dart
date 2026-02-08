import 'package:go_router/go_router.dart';
import '../../../core/navigation/route_paths.dart';
import 'pages/settings_page.dart';

List<RouteBase> getSettingsRoutes() {
  return [
    GoRoute(
      path: RoutePaths.settings,
      builder: (context, state) => const SettingsPage(),
    ),
  ];
}
