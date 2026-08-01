import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'app_page.dart';
import 'decorative_route.dart';
import 'invite_nav_redirect.dart';
import 'navigation_trace.dart';
import 'route_paths.dart';
import '../../features/home/routes.dart';
import '../../features/profile/routes.dart';
import '../../features/settings/routes.dart';
import '../../features/onboarding/routes.dart';
import '../../features/settings/providers/settings_framework_providers.dart';
import '../../features/settings/settings_definitions.dart';
import '../../features/groups/pages/group_create_page.dart';
import '../../features/groups/pages/group_analytics_page.dart';
import '../../features/groups/pages/group_detail_page.dart';
import '../../features/groups/pages/group_settings_page.dart';
import '../../features/groups/pages/invite_accept_page.dart';
import '../../features/groups/pages/invite_group_preview_page.dart';
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
  void deactivate() {
    // Unfocus before the Focus widget is torn down so InheritedElement
    // can deactivate without _dependents.isEmpty asserting (e.g. when
    // navigating away from the shell to onboarding or a full-screen route).
    _focusNode.unfocus();
    super.deactivate();
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
        SingleActivator(LogicalKeyboardKey.digit1, alt: true): GoHomeIntent(),
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

  final router = GoRouter(
    refreshListenable: refreshNotifier,
    initialLocation: RoutePaths.home,
    redirect: (context, state) {
      final onOnboarding =
          state.matchedLocation == RoutePaths.onboarding ||
          state.matchedLocation.startsWith('${RoutePaths.onboarding}/');
      final onPrivacyPolicy = state.matchedLocation == RoutePaths.privacyPolicy;
      final settings = ref.read(hisabSettingsProvidersProvider);
      if (settings != null) {
        // Pending invite first — must beat last-route restore (camera kill),
        // otherwise Join→auth can land on a stale group detail instead of invite.
        final pendingToken = ref.read(
          settings.provider(pendingInviteTokenSettingDef),
        );
        final pendingTarget = pendingInviteRedirectTarget(
          pendingToken: pendingToken,
          currentPath: state.uri.path,
          onOnboarding: onOnboarding,
          onPrivacyPolicy: onPrivacyPolicy,
        );
        if (pendingTarget != null) {
          ref
              .read(settings.provider(pendingInviteTokenSettingDef).notifier)
              .set('');
          // Drop stale restore so it cannot override invite on the next refresh.
          final lastPath = ref.read(settings.provider(lastRoutePathSettingDef));
          if (lastPath.isNotEmpty) {
            ref
                .read(settings.provider(lastRoutePathSettingDef).notifier)
                .set('');
          }
          Log.info(
            'Setting changed: ${pendingInviteTokenSettingDef.key}=(cleared for redirect)',
          );
          return pendingTarget;
        }
        // Restore route after process kill (e.g. returning from camera)
        final lastPath = ref.read(settings.provider(lastRoutePathSettingDef));
        if (shouldRestoreLastRoute(
          lastPath: lastPath,
          pendingToken: pendingToken,
          onboardingCompleted: onboardingCompleted,
        )) {
          ref.read(settings.provider(lastRoutePathSettingDef).notifier).set('');
          Log.info(
            'Setting changed: ${lastRoutePathSettingDef.key}=(cleared for redirect)',
          );
          return lastPath;
        }
      }
      if (!onboardingCompleted && !onOnboarding && !onPrivacyPolicy) {
        // Allow staying on invite routes so readonly preview works without onboarding
        if (isInviteRoutePath(state.uri.path)) return null;
        return RoutePaths.onboarding;
      }
      if (onboardingCompleted && onOnboarding) {
        final settingsForInvite = ref.read(hisabSettingsProvidersProvider);
        final pending = settingsForInvite == null
            ? ''
            : ref.read(
                settingsForInvite.provider(pendingInviteTokenSettingDef),
              );
        final afterOnboarding = afterOnboardingRedirectTarget(
          onboardingCompleted: onboardingCompleted,
          onOnboarding: onOnboarding,
          pendingToken: pending,
        );
        if (afterOnboarding != null &&
            isInviteRoutePath(afterOnboarding) &&
            settingsForInvite != null) {
          ref
              .read(
                settingsForInvite
                    .provider(pendingInviteTokenSettingDef)
                    .notifier,
              )
              .set('');
          Log.info(
            'Setting changed: ${pendingInviteTokenSettingDef.key}=(cleared after onboarding)',
          );
        }
        return afterOnboarding;
      }
      return null;
    },
    routes: [
      ...getOnboardingRoutes(),
      GoRoute(
        path: RoutePaths.privacyPolicy,
        pageBuilder: (context, state) => appFadeSlidePage(
          key: state.pageKey,
          child: const PrivacyPolicyPage(),
        ),
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
        routes: [
          ...getHomeRoutes(),
          ...getSettingsRoutes(),
          ...getProfileRoutes(),
        ],
      ),
      GoRoute(
        path: '/invite',
        redirect: (context, state) {
          final token = state.uri.queryParameters['token']?.trim() ?? '';
          if (token.isNotEmpty) {
            return RoutePaths.inviteAccept(token);
          }
          return null;
        },
        pageBuilder: (context, state) {
          final token =
              state.pathParameters['token'] ??
              state.uri.queryParameters['token'] ??
              '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: InviteAcceptPage(token: token),
          );
        },
      ),
      GoRoute(
        path: '/invite/:token/preview/expenses/:eid',
        pageBuilder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          final expenseId = state.pathParameters['eid'] ?? '';
          return appNoTransitionPage(
            key: state.pageKey,
            child: InvitePreviewExpenseDetailPage(
              token: token,
              expenseId: expenseId,
            ),
          );
        },
      ),
      GoRoute(
        path: '/invite/:token/preview',
        redirect: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          if (token.isEmpty) return RoutePaths.home;
          return RoutePaths.invitePreviewExpenses(token);
        },
      ),
      GoRoute(
        path: '/invite/:token/preview/expenses',
        pageBuilder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: InviteGroupPreviewPage(
              token: token,
              initialTab: GroupDetailTab.expenses,
            ),
          );
        },
      ),
      GoRoute(
        path: '/invite/:token/preview/balance',
        pageBuilder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: InviteGroupPreviewPage(
              token: token,
              initialTab: GroupDetailTab.balance,
            ),
          );
        },
      ),
      GoRoute(
        path: '/invite/:token/preview/people',
        pageBuilder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: InviteGroupPreviewPage(
              token: token,
              initialTab: GroupDetailTab.people,
            ),
          );
        },
      ),
      GoRoute(
        path: '/invite/:token',
        pageBuilder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: InviteAcceptPage(token: token),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.scanInvite,
        pageBuilder: (context, state) => appFadeSlidePage(
          key: state.pageKey,
          child: const InviteScanPage(),
        ),
      ),
      // Custom-domain invite link: hisab.shenepoy.com/functions/v1/invite-redirect?token=...
      // Redirects to Supabase Edge Function so token is validated and user sent to redirect.html.
      GoRoute(
        path: '/functions/v1/invite-redirect',
        pageBuilder: (context, state) => appFadeSlidePage(
          key: state.pageKey,
          child: InviteRedirectProxyPage(uri: state.uri),
        ),
      ),
      // One shell per wizard so PageView state is not disposed on step changes.
      GoRoute(
        path: RoutePaths.groupCreate,
        pageBuilder: (context, state) => appFadeSlidePage(
          key: state.pageKey,
          child: const GroupCreatePage(isPersonal: false),
        ),
      ),
      GoRoute(
        path: RoutePaths.groupCreatePersonal,
        pageBuilder: (context, state) => appFadeSlidePage(
          key: state.pageKey,
          child: const GroupCreatePage(isPersonal: true),
        ),
      ),
      // Per-step URLs for bookmarks / reload. In-wizard step changes still use
      // decorative hash sync on the canonical route so PageView state is not
      // disposed; these builders only matter on cold start / F5.
      GoRoute(
        path: RoutePaths.groupCreateDetails,
        pageBuilder: (context, state) => appFadeSlidePage(
          key: state.pageKey,
          child: const GroupCreatePage(isPersonal: false, initialStep: 0),
        ),
      ),
      GoRoute(
        path: RoutePaths.groupCreateParticipants,
        pageBuilder: (context, state) => appFadeSlidePage(
          key: state.pageKey,
          child: const GroupCreatePage(isPersonal: false, initialStep: 1),
        ),
      ),
      GoRoute(
        path: RoutePaths.groupCreateStyle,
        pageBuilder: (context, state) => appFadeSlidePage(
          key: state.pageKey,
          child: const GroupCreatePage(isPersonal: false, initialStep: 2),
        ),
      ),
      GoRoute(
        path: RoutePaths.groupCreateReview,
        pageBuilder: (context, state) => appFadeSlidePage(
          key: state.pageKey,
          child: const GroupCreatePage(isPersonal: false, initialStep: 3),
        ),
      ),
      GoRoute(
        path: RoutePaths.groupCreatePersonalDetails,
        pageBuilder: (context, state) => appFadeSlidePage(
          key: state.pageKey,
          child: const GroupCreatePage(isPersonal: true, initialStep: 0),
        ),
      ),
      GoRoute(
        path: RoutePaths.groupCreatePersonalStyle,
        pageBuilder: (context, state) => appFadeSlidePage(
          key: state.pageKey,
          child: const GroupCreatePage(isPersonal: true, initialStep: 1),
        ),
      ),
      GoRoute(
        path: RoutePaths.groupCreatePersonalReview,
        pageBuilder: (context, state) => appFadeSlidePage(
          key: state.pageKey,
          child: const GroupCreatePage(isPersonal: true, initialStep: 2),
        ),
      ),
      GoRoute(
        path: '/groups/:id',
        redirect: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          if (id.isEmpty) return RoutePaths.home;
          return RoutePaths.groupExpenses(id);
        },
      ),
      GoRoute(
        path: '/groups/:id/people',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: GroupDetailPage(
              groupId: id,
              initialTab: GroupDetailTab.people,
            ),
          );
        },
      ),
      GoRoute(
        path: '/groups/:id/balance',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: GroupDetailPage(
              groupId: id,
              initialTab: GroupDetailTab.balance,
            ),
          );
        },
      ),
      GoRoute(
        path: '/groups/:id/settings',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: GroupSettingsPage(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: '/groups/:id/analytics',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: GroupAnalyticsPage(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: '/groups/:id/invites',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: InviteManagementPage(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: '/groups/:id/expenses/add',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: ExpenseFormPage(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: '/groups/:id/expenses',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: GroupDetailPage(
              groupId: groupId,
              initialTab: GroupDetailTab.expenses,
            ),
          );
        },
        routes: [
          ShellRoute(
            builder: (context, state, child) {
              final groupId = state.pathParameters['id'] ?? '';
              final pathSegments = state.uri.pathSegments;
              final expenseId =
                  state.pathParameters['eid'] ??
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
                pageBuilder: (context, state) {
                  final groupId = state.pathParameters['id'] ?? '';
                  final expenseId = state.pathParameters['eid'] ?? '';
                  return appNoTransitionPage(
                    key: state.pageKey,
                    child: ExpenseDetailBody(
                      groupId: groupId,
                      expenseId: expenseId,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/groups/:id/expenses/:eid/edit',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          final expenseId = state.pathParameters['eid'] ?? '';
          return appFadeSlidePage(
            key: state.pageKey,
            child: ExpenseFormPage(groupId: groupId, expenseId: expenseId),
          );
        },
      ),
    ],
  );

  void traceListener() {
    try {
      NavigationTrace.instance.recordUri(
        router.routerDelegate.currentConfiguration.uri.toString(),
      );
    } catch (_) {}
  }

  traceListener();
  router.routerDelegate.addListener(traceListener);
  if (kIsWeb) {
    sanitizeHashStrategyBrowserUrl();
    void syncBrowserUrl() => syncBrowserUrlToGoRouter(router);
    // Ensure group/expense/settings/analytics pushes update the hash even if
    // Flutter's own routeInformation pipeline was previously disrupted.
    router.routerDelegate.addListener(syncBrowserUrl);
    // Sync the route that is already matched at creation time.
    syncBrowserUrl();
    ref.onDispose(() {
      router.routerDelegate.removeListener(syncBrowserUrl);
    });
  }

  return router;
}
