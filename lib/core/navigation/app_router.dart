import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:go_router/go_router.dart';
import 'route_paths.dart';
import '../../features/home/routes.dart';
import '../../features/settings/routes.dart';
import '../../features/onboarding/routes.dart';
import '../../features/settings/providers/settings_framework_providers.dart';
import '../../features/settings/settings_definitions.dart';
import '../../features/groups/pages/group_create_page.dart';
import '../../features/groups/pages/group_detail_page.dart';
import '../../features/groups/pages/group_settings_page.dart';
import '../../features/groups/pages/invite_accept_page.dart';
import '../../features/expenses/pages/expense_form_page.dart';
import '../../features/expenses/pages/expense_detail_page.dart';
import 'main_scaffold.dart';

part 'app_router.g.dart';

/// Notifier that triggers GoRouter refresh when locale changes.
/// Ensures navigation labels and all visible content update in realtime.
@riverpod
ValueNotifier<String> localeRefreshNotifier(Ref ref) {
  final notifier = ValueNotifier<String>(ref.read(languageProvider));
  ref.listen(languageProvider, (_, next) => notifier.value = next);
  return notifier;
}

@riverpod
GoRouter router(Ref ref) {
  final refreshNotifier = ref.watch(localeRefreshProvider);
  final onboardingCompleted = ref.watch(onboardingCompletedProvider);

  return GoRouter(
    refreshListenable: refreshNotifier,
    initialLocation: RoutePaths.home,
    redirect: (context, state) {
      final onOnboarding = state.matchedLocation == RoutePaths.onboarding;
      // Pending invite from deep link: send to invite page and clear
      final settings = ref.read(hisabSettingsProvidersProvider);
      if (settings != null) {
        final pendingToken = ref.read(
          settings.provider(pendingInviteTokenSettingDef),
        );
        if (pendingToken.isNotEmpty && onboardingCompleted) {
          ref
              .read(settings.provider(pendingInviteTokenSettingDef).notifier)
              .set('');
          return RoutePaths.inviteAccept(pendingToken);
        }
      }
      if (!onboardingCompleted && !onOnboarding) {
        return RoutePaths.onboarding;
      }
      if (onboardingCompleted && onOnboarding) {
        return RoutePaths.home;
      }
      return null;
    },
    routes: [
      ...getOnboardingRoutes(),
      ShellRoute(
        builder: (context, state, child) {
          final location = state.uri.path;
          int selectedIndex = 0;
          if (location.startsWith(RoutePaths.settings)) {
            selectedIndex = 1;
          }
          return MainScaffold(
            selectedIndex: selectedIndex,
            location: location,
            child: child,
          );
        },
        routes: [...getHomeRoutes(), ...getSettingsRoutes()],
      ),
      GoRoute(
        path: '/invite',
        builder: (context, state) {
          final token =
              state.pathParameters['token'] ??
              state.uri.queryParameters['token'] ??
              '';
          return InviteAcceptPage(token: token);
        },
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return InviteAcceptPage(token: token);
        },
      ),
      GoRoute(
        path: '/groups/create',
        builder: (context, state) => const GroupCreatePage(),
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return GroupDetailPage(groupId: id);
        },
      ),
      GoRoute(
        path: '/groups/:id/settings',
        builder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          return GroupSettingsPage(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/groups/:id/expenses/add',
        builder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          return ExpenseFormPage(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/groups/:id/expenses/:eid',
        builder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          final expenseId = state.pathParameters['eid'] ?? '';
          return ExpenseDetailPage(groupId: groupId, expenseId: expenseId);
        },
      ),
      GoRoute(
        path: '/groups/:id/expenses/:eid/edit',
        builder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          final expenseId = state.pathParameters['eid'] ?? '';
          return ExpenseFormPage(groupId: groupId, expenseId: expenseId);
        },
      ),
    ],
  );
}
