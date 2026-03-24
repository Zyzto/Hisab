import 'package:go_router/go_router.dart';
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
      builder: (context, state) => const OnboardingPage(initialPage: 0),
    ),
    GoRoute(
      path: RoutePaths.onboardingPreferences,
      builder: (context, state) => const OnboardingPage(initialPage: 1),
    ),
    GoRoute(
      path: RoutePaths.onboardingPermissions,
      builder: (context, state) => const OnboardingPage(initialPage: 2),
    ),
    GoRoute(
      path: RoutePaths.onboardingConnect,
      builder: (context, state) => const OnboardingPage(initialPage: 3),
    ),
  ];
}
