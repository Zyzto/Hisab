import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/balance/routes.dart';
import '../../features/expenses/routes.dart';
import '../../features/groups/routes.dart';
import '../../features/home/routes.dart';
import '../../features/onboarding/routes.dart';
import '../../features/settings/routes.dart';
import '../../features/settings/widgets/privacy_policy_page.dart';
import '../settings/providers/settings_framework_providers.dart';
import '../navigation/app_page.dart';
import '../navigation/decorative_route.dart';
import '../navigation/navigation_trace.dart';
import '../navigation/route_paths.dart';
import 'main_scaffold.dart';

part 'app_router.g.dart';

class GoHomeIntent extends Intent {
  const GoHomeIntent();
}

class GoSettingsIntent extends Intent {
  const GoSettingsIntent();
}

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

@riverpod
ValueNotifier<String> localeRefreshNotifier(Ref ref) {
  final notifier = ValueNotifier<String>(ref.read(languageProvider));
  ref.listen(languageProvider, (_, next) => notifier.value = next);
  ref.onDispose(notifier.dispose);
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
      final onOnboarding = state.matchedLocation == RoutePaths.onboarding ||
          state.matchedLocation.startsWith('${RoutePaths.onboarding}/');
      final onPrivacyPolicy = state.matchedLocation == RoutePaths.privacyPolicy;
      if (!onboardingCompleted && !onOnboarding && !onPrivacyPolicy) {
        return RoutePaths.onboarding;
      }
      if (onboardingCompleted && onOnboarding) return RoutePaths.home;
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
          return _ShellWithShortcuts(
            selectedIndex: location.startsWith(RoutePaths.settings) ? 1 : 0,
            location: location,
            child: child,
          );
        },
        routes: [
          ...getHomeRoutes(),
          ...getSettingsRoutes(),
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
    } catch (error) {
      Log.debug('Navigation trace failed', error: error);
    }
  }

  traceListener();
  router.routerDelegate.addListener(traceListener);
  ref.onDispose(() => router.routerDelegate.removeListener(traceListener));

  if (kIsWeb) {
    sanitizeHashStrategyBrowserUrl();
    syncBrowserUrlToGoRouter(router);
  }

  return router;
}
