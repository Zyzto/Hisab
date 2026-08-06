import 'package:go_router/go_router.dart';
import '../../../core/navigation/app_page.dart';
import '../../../core/navigation/route_paths.dart';
import 'pages/settings_page.dart';

List<RouteBase> getSettingsRoutes() {
  return [
    GoRoute(
      path: RoutePaths.settings,
      pageBuilder: (context, state) =>
          appNoTransitionPage(key: state.pageKey, child: const SettingsPage()),
    ),
    // Privacy policy lives on the top-level route in app_router (outside shell).
  ];
}
