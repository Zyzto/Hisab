import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'decorative_route.dart';

/// Returns true when [ancestor] is a strict path prefix of [path].
///
/// Used so back from nested routes (e.g. expense under group expenses) can
/// [GoRouter.go] to the parent even when [canPop] is true but [pop] no-ops
/// after a cold load / reload of the nested match stack.
@visibleForTesting
bool isStrictAncestorPath(String ancestor, String path) {
  if (ancestor.isEmpty || path.isEmpty || ancestor == path) return false;
  if (ancestor == '/') return path.startsWith('/') && path != '/';
  final normalized = ancestor.endsWith('/')
      ? ancestor.substring(0, ancestor.length - 1)
      : ancestor;
  return path.startsWith('$normalized/');
}

/// Whether the route stack can pop (GoRouter when present, else Navigator).
///
/// Prefer this over [GoRouterHelper.canPop], which throws when no GoRouter is
/// in the tree (common in widget tests that use plain [MaterialApp]).
bool routerCanPop(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) return router.canPop();
  return Navigator.of(context).canPop();
}

/// Pops when there is a real stack entry; otherwise [context.go] to [fallbackPath].
///
/// Prefer [context.go] when [fallbackPath] is an ancestor of the current route.
/// Expense detail is a nested child of `/groups/:id/expenses`, so after reload
/// GoRouter often reports [canPop] == true while [pop] does not leave the page.
void popOrGo(BuildContext context, String fallbackPath) {
  if (fallbackPath.isEmpty) return;
  final router = GoRouter.maybeOf(context);
  final currentPath = router != null ? goRouterVisiblePath(router) : '';

  if (router != null &&
      currentPath.isNotEmpty &&
      isStrictAncestorPath(fallbackPath, currentPath)) {
    context.go(fallbackPath);
    return;
  }

  if (routerCanPop(context)) {
    if (router != null) {
      context.pop();
    } else {
      Navigator.of(context).pop();
    }
  } else if (router != null && currentPath != fallbackPath) {
    context.go(fallbackPath);
  }
}

/// On web cold start / reload of a nested route, insert [parentPath] under the
/// current history entry so the browser back button returns to the parent
/// instead of leaving the app.
///
/// Skips when the top match is an imperative [context.push] (history already
/// has the previous page). Nested declarative matches still report
/// [canPop]==true after reload, so we must not key off [canPop] alone.
void seedParentHistoryForBrowserBack({
  required BuildContext context,
  required String parentPath,
  required String currentPath,
}) {
  if (!kIsWeb) return;
  if (parentPath.isEmpty || currentPath.isEmpty || parentPath == currentPath) {
    return;
  }
  final router = GoRouter.maybeOf(context);
  if (router != null && _hasImperativeTopMatch(router)) {
    return;
  }
  // Avoid double-seeding on rebuilds.
  if (webVisibleAppRoutePath() == currentPath &&
      _seededCurrentPaths.contains(currentPath)) {
    return;
  }
  seedParentBrowserHistory(parentPath: parentPath, currentPath: currentPath);
  _seededCurrentPaths.add(currentPath);
}

bool _hasImperativeTopMatch(GoRouter router) {
  final configuration = router.routerDelegate.currentConfiguration;
  if (configuration.isEmpty) return false;
  RouteMatchBase route = configuration.matches.last;
  while (route is ShellRouteMatch && route.matches.isNotEmpty) {
    route = route.matches.last;
  }
  return route is ImperativeRouteMatch;
}

final Set<String> _seededCurrentPaths = <String>{};
