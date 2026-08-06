import 'package:go_router/go_router.dart';
import '../../core/navigation/app_page.dart';
import '../../core/navigation/route_paths.dart';
import 'pages/profile_expenses_page.dart';
import 'pages/profile_page.dart';

List<RouteBase> getProfileRoutes() {
  return [
    GoRoute(
      path: RoutePaths.profile,
      pageBuilder: (context, state) =>
          appFadeSlidePage(key: state.pageKey, child: const ProfilePage()),
      routes: [
        GoRoute(
          path: 'expenses',
          pageBuilder: (context, state) => appFadeSlidePage(
            key: state.pageKey,
            child: const ProfileExpensesPage(),
          ),
        ),
      ],
    ),
  ];
}
