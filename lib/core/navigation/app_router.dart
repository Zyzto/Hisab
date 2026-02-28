import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
import '../../features/groups/pages/invite_management_page.dart';
import '../../features/groups/pages/invite_redirect_proxy_page.dart';
import '../../features/groups/pages/invite_scan_page.dart';
import '../../features/expenses/pages/expense_form_page.dart';
import '../../features/expenses/pages/expense_detail_shell.dart';
import '../../features/expenses/widgets/expense_detail_body.dart';
import '../../features/settings/widgets/privacy_policy_page.dart';
import 'main_scaffold.dart';

part 'app_router.g.dart';

// --- Keyboard shortcut intents (desktop/web) ---

class GoHomeIntent extends Intent {
  const GoHomeIntent();
}

class GoSettingsIntent extends Intent {
  const GoSettingsIntent();
}

/// Wraps [MainScaffold] in [Shortcuts], [Actions], and [Focus] so the shell
/// can receive keyboard shortcuts (e.g. Alt+1 = home, Alt+2 = settings).
/// FocusNode is owned in State because the ShellRoute builder is stateless.
class _ShellWithShortcuts extends StatefulWidget {
  const _ShellWithShortcuts({
    required this.selectedIndex,
    required this.location,
    required this.child,
  });

  final int selectedIndex;
  final String location;
  final Widget child;

  @override
  State<_ShellWithShortcuts> createState() => _ShellWithShortcutsState();
}

class _ShellWithShortcutsState extends State<_ShellWithShortcuts> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.digit1, alt: true):
            GoHomeIntent(),
        SingleActivator(LogicalKeyboardKey.digit2, alt: true):
            GoSettingsIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          GoHomeIntent: CallbackAction<GoHomeIntent>(
            onInvoke: (_) {
              context.go(RoutePaths.home);
              return null;
            },
          ),
          GoSettingsIntent: CallbackAction<GoSettingsIntent>(
            onInvoke: (_) {
              context.go(RoutePaths.settings);
              return null;
            },
          ),
        },
        // autofocus: false so we don't steal focus from text fields (expense form,
        // group create, modals). Shortcuts (Alt+1/2) still work when shell has focus.
        child: Focus(
          focusNode: _focusNode,
          autofocus: false,
          child: MainScaffold(
            selectedIndex: widget.selectedIndex,
            location: widget.location,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

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
      final onPrivacyPolicy =
          state.matchedLocation == RoutePaths.privacyPolicy;
      final settings = ref.read(hisabSettingsProvidersProvider);
      if (settings != null) {
        // Restore route after process kill (e.g. returning from camera)
        final lastPath = ref.read(
          settings.provider(lastRoutePathSettingDef),
        );
        if (lastPath.isNotEmpty &&
            lastPath != RoutePaths.home &&
            onboardingCompleted) {
          ref
              .read(settings.provider(lastRoutePathSettingDef).notifier)
              .set('');
          return lastPath;
        }
        // Pending invite from deep link: send to invite page and clear
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
      if (!onboardingCompleted && !onOnboarding && !onPrivacyPolicy) {
        return RoutePaths.onboarding;
      }
      if (onboardingCompleted && onOnboarding) {
        return RoutePaths.home;
      }
      return null;
    },
    routes: [
      ...getOnboardingRoutes(),
      GoRoute(
        path: RoutePaths.privacyPolicy,
        builder: (context, state) => const PrivacyPolicyPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final location = state.uri.path;
          int selectedIndex = 0;
          if (location.startsWith(RoutePaths.settings)) {
            selectedIndex = 1;
          }
          return _ShellWithShortcuts(
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
        path: RoutePaths.scanInvite,
        builder: (context, state) => const InviteScanPage(),
      ),
      // Custom-domain invite link: hisab.shenepoy.com/functions/v1/invite-redirect?token=...
      // Redirects to Supabase Edge Function so token is validated and user sent to redirect.html.
      GoRoute(
        path: '/functions/v1/invite-redirect',
        builder: (context, state) => InviteRedirectProxyPage(uri: state.uri),
      ),
      GoRoute(
        path: '/groups/create',
        builder: (context, state) => const GroupCreatePage(isPersonal: false),
      ),
      GoRoute(
        path: '/groups/create-personal',
        builder: (context, state) => const GroupCreatePage(isPersonal: true),
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
        path: '/groups/:id/invites',
        builder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          return InviteManagementPage(groupId: groupId);
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
        path: '/groups/:id/expenses',
        builder: (context, state) => const SizedBox.shrink(),
        routes: [
          ShellRoute(
            builder: (context, state, child) {
              final groupId = state.pathParameters['id'] ?? '';
              final pathSegments = state.uri.pathSegments;
              final expenseId = state.pathParameters['eid'] ??
                  (pathSegments.length >= 4 ? pathSegments[3] : '');
              return ExpenseDetailShell(
                groupId: groupId,
                expenseId: expenseId,
                child: child,
              );
            },
            routes: [
              GoRoute(
                path: ':eid',
                builder: (context, state) {
                  final groupId = state.pathParameters['id'] ?? '';
                  final expenseId = state.pathParameters['eid'] ?? '';
                  return ExpenseDetailBody(
                    groupId: groupId,
                    expenseId: expenseId,
                  );
                },
              ),
            ],
          ),
        ],
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
