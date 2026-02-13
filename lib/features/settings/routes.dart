import 'package:go_router/go_router.dart';
import '../../../core/navigation/route_paths.dart';
import 'pages/settings_page.dart';
import 'widgets/privacy_policy_page.dart';

List<RouteBase> getSettingsRoutes() {
  return [
    GoRoute(
      path: RoutePaths.settings,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: RoutePaths.privacyPolicy,
      builder: (context, state) => const PrivacyPolicyPage(),
    ),
  ];
}
