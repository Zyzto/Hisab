import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:go_router/go_router.dart';
import 'app_page.dart';
import 'decorative_route.dart';
import 'invite_nav_redirect.dart';
import 'last_route_restore.dart';
import 'navigation_trace.dart';
import 'route_paths.dart';
import '../../features/home/routes.dart';
import '../../features/profile/routes.dart';
import '../../features/settings/routes.dart';
import '../../features/onboarding/routes.dart';
import '../../features/groups/routes.dart';
import '../../features/expenses/routes.dart';
import '../../features/balance/routes.dart';
import '../settings/providers/settings_framework_providers.dart';
import '../settings/settings_definitions.dart';
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
        final autoJoinFlag = ref.read(
          settings.provider(pendingInviteAutoJoinSettingDef),
        );
        // Stale invite last-route must never restore.
        final lastPath = ref.read(settings.provider(lastRoutePathSettingDef));
        if (isInviteRoutePath(lastPath)) {
          scheduleClearLastRouteSettings(
            ref,
            clearLastRoute: true,
            lastRouteLog: '(cleared invite last-route)',
          );
        }
        // Only force /invite while join is still intended (mid-auth / auto-join).
        final pendingTarget =
            shouldRedirectPendingInvite(
              pendingToken: pendingToken,
              autoJoinFlag: autoJoinFlag,
            )
            ? pendingInviteRedirectTarget(
                pendingToken: pendingToken,
                currentPath: state.uri.path,
                onOnboarding: onOnboarding,
                onPrivacyPolicy: onPrivacyPolicy,
              )
            : null;
        if (pendingTarget != null) {
          // Keep pending token through auth return; only clear last-route.
          scheduleClearLastRouteSettings(
            ref,
            clearLastRoute: true,
            lastRouteLog: '(cleared for invite redirect)',
          );
          return pendingTarget;
        }
        // Drop stale pending token that has no join intent and is not the
        // current invite route (page may still persist token for auth resume).
        if (pendingToken.isNotEmpty &&
            !autoJoinFlag &&
            !isInviteRoutePath(state.uri.path)) {
          scheduleClearLastRouteSettings(
            ref,
            clearPendingInvite: true,
            pendingInviteLog: '(cleared stale without auto-join)',
          );
        }
        // Restore route after process kill (e.g. returning from camera)
        if (shouldRestoreLastRoute(
          lastPath: lastPath,
          pendingToken: pendingToken,
          onboardingCompleted: onboardingCompleted,
        )) {
          // Already on the restored path (redirect re-entry): just clear.
          if (state.uri.path == lastPath) {
            scheduleClearLastRouteSettings(
              ref,
              clearLastRoute: true,
              lastRouteLog: '(cleared for redirect)',
            );
            return null;
          }
          scheduleClearLastRouteSettings(
            ref,
            clearLastRoute: true,
            lastRouteLog: '(cleared for redirect)',
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
        // Keep pending token so InviteAcceptPage can auto-join after onboarding.
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
      ...getGroupRoutes(),
      ...getExpenseRoutes(),
      ...getBalanceRoutes(),
    ],
  );

  void traceListener() {
    try {
      NavigationTrace.instance.recordUri(
        router.routerDelegate.currentConfiguration.uri.toString(),
      );
    } catch (e) {
      Log.debug('NavigationTrace recordUri failed', error: e);
    }
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
