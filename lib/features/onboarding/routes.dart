import 'package:go_router/go_router.dart';
import '../../../core/navigation/app_page.dart';
import '../../../core/navigation/route_paths.dart';
import 'pages/onboarding_page.dart';

List<RouteBase> getOnboardingRoutes() {
  return [
    GoRoute(
      path: RoutePaths.onboarding,
      redirect: (context, state) => RoutePaths.onboardingWelcome,
    ),
    GoRoute(
      path: RoutePaths.onboardingWelcome,
      pageBuilder: (context, state) => appNoTransitionPage(
        key: state.pageKey,
        child: const OnboardingPage(initialPage: 0),
      ),
    ),
    GoRoute(
      path: RoutePaths.onboardingPreferences,
      pageBuilder: (context, state) => appNoTransitionPage(
        key: state.pageKey,
        child: const OnboardingPage(initialPage: 1),
      ),
    ),
    GoRoute(
      path: RoutePaths.onboardingPermissions,
      pageBuilder: (context, state) => appNoTransitionPage(
        key: state.pageKey,
        child: const OnboardingPage(initialPage: 2),
      ),
    ),
    GoRoute(
      path: RoutePaths.onboardingConnect,
      pageBuilder: (context, state) => appNoTransitionPage(
        key: state.pageKey,
        child: const OnboardingPage(initialPage: 3),
      ),
    ),
  ];
}