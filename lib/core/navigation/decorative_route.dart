import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'decorative_route_logic.dart';
import 'decorative_route_platform.dart';

export 'decorative_route_logic.dart';
export 'decorative_route_platform.dart'
    show
        browserLocationUri,
        replaceBrowserAppPath,
        safeHistoryReplaceUrl,
        sanitizeHashStrategyBrowserUrl,
        seedParentBrowserHistory;

/// In-app route from the browser address bar, or null when not on web.
String? webVisibleAppRoutePath() {
  if (!kIsWeb) return null;
  final browser = browserLocationUri();
  if (browser == null) return null;
  return appRoutePathFromBrowserUri(browser);
}

/// Path currently shown in the address bar (web) or known to GoRouter.
String visibleRoutePath(BuildContext context) {
  final fromBrowser = webVisibleAppRoutePath();
  if (fromBrowser != null) return fromBrowser;
  return GoRouter.maybeOf(
        context,
      )?.routerDelegate.currentConfiguration.uri.path ??
      '';
}

/// Last GoRouter path we wrote to the address bar. Used so locale/refresh
/// rebuilds (same matched path) do not clobber decorative tab/step hashes.
String? _lastSyncedRouterPath;

/// Top-most in-app path from [router], including imperative [context.push] routes.
///
/// [GoRouterDelegate.currentConfiguration.uri] stays on the declarative base
/// when [GoRouter.optionURLReflectsImperativeAPIs] is false; drill into
/// [ImperativeRouteMatch] so browser sync still sees group/expense pushes.
String goRouterVisiblePath(GoRouter router) {
  final configuration = router.routerDelegate.currentConfiguration;
  if (configuration.isEmpty) return '';
  RouteMatchBase route = configuration.matches.last;
  while (route is ShellRouteMatch && route.matches.isNotEmpty) {
    route = route.matches.last;
  }
  if (route is ImperativeRouteMatch) {
    return route.matches.uri.path;
  }
  return configuration.uri.path;
}

/// Keep the browser address bar healthy after GoRouter navigations.
///
/// When [GoRouter.optionURLReflectsImperativeAPIs] is true (Hisab web),
/// GoRouter owns history (`pushState` for [context.push]). This method only
/// sanitizes pathname/hash hybrids — it must **not** [replaceBrowserAppPath],
/// or it can overwrite the previous history entry and break the back button.
///
/// Fallback (flag false): align the hash via replace when the top path changes.
void syncBrowserUrlToGoRouter(GoRouter router) {
  if (!kIsWeb) return;
  sanitizeHashStrategyBrowserUrl();
  if (GoRouter.optionURLReflectsImperativeAPIs) {
    _lastSyncedRouterPath = goRouterVisiblePath(router);
    return;
  }

  final path = goRouterVisiblePath(router);
  if (path.isEmpty) return;
  if (path == _lastSyncedRouterPath) return;
  _lastSyncedRouterPath = path;
  if (webVisibleAppRoutePath() == path) return;
  replaceBrowserAppPath(path);
}

/// Updates the address bar to [targetPath] without [context.go] / [context.push].
///
/// On web this rewrites only the hash via [safeHistoryReplaceUrl] so:
/// - in-page [PageView] tab/step/expense swipe state is not disposed
/// - Flutter [History.state] is preserved (required for later GoRouter URL updates)
///
/// Native platforms no-op.
void syncDecorativeRoutePath(BuildContext context, String targetPath) {
  if (targetPath.isEmpty || !targetPath.startsWith('/')) return;
  if (!kIsWeb) return;
  if (webVisibleAppRoutePath() == targetPath) {
    sanitizeHashStrategyBrowserUrl();
    return;
  }
  replaceBrowserAppPath(targetPath);
}
