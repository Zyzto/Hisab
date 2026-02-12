import 'package:go_router/go_router.dart';
import 'pages/onboarding_page.dart';

List<RouteBase> getOnboardingRoutes() {
  return [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
  ];
}
