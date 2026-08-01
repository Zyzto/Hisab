import 'package:web/web.dart' as web;

import 'decorative_route_logic.dart' show hashStrategyPathname;

/// Current browser URL from [window.location].
Uri? browserLocationUri() => Uri.parse(web.window.location.href);

/// [History.replaceState] that **always** keeps the existing history state.
///
/// Passing `null` state breaks Flutter/GoRouter web navigation so later
/// [context.go]/[context.push] stop updating the address bar.
void safeHistoryReplaceUrl(String url) {
  web.window.history.replaceState(web.window.history.state, '', url);
}

/// Clears pathname/hash hybrids like `/settings#/groups/...`.
void sanitizeHashStrategyBrowserUrl() {
  final loc = web.window.location;
  final hash = loc.hash;
  if (!hash.startsWith('#/')) return;
  final basePath = hashStrategyPathname(loc.pathname);
  if (loc.pathname == basePath) return;

  final buffer = StringBuffer(basePath);
  if (loc.search.isNotEmpty) buffer.write(loc.search);
  buffer.write(hash);
  safeHistoryReplaceUrl(buffer.toString());
}

/// Writes [appPath] into the hash (`/#/route`) without notifying GoRouter.
void replaceBrowserAppPath(String appPath) {
  assert(appPath.startsWith('/'), 'appPath must be absolute: $appPath');
  final loc = web.window.location;
  final basePath = hashStrategyPathname(loc.pathname);
  final search = loc.search;
  final nextHash = '#$appPath';
  if (loc.pathname == basePath && loc.hash == nextHash) return;

  final buffer = StringBuffer(basePath);
  if (search.isNotEmpty) buffer.write(search);
  buffer.write(nextHash);
  safeHistoryReplaceUrl(buffer.toString());
}

String _hashUrl(String appPath) {
  final loc = web.window.location;
  final basePath = hashStrategyPathname(loc.pathname);
  final buffer = StringBuffer(basePath);
  if (loc.search.isNotEmpty) buffer.write(loc.search);
  buffer.write('#$appPath');
  return buffer.toString();
}

/// After reload on a nested route, rewrite history to `[parent, current]` so
/// browser back lands on [parentPath] instead of leaving the app.
///
/// Preserves [History.state]. Idempotent when the current hash is already
/// [currentPath] and the previous entry was seeded in this session.
void seedParentBrowserHistory({
  required String parentPath,
  required String currentPath,
}) {
  assert(parentPath.startsWith('/') && currentPath.startsWith('/'));
  final loc = web.window.location;
  if (loc.hash == '#$currentPath') {
    // Already on current; put parent under it.
    final state = web.window.history.state;
    safeHistoryReplaceUrl(_hashUrl(parentPath));
    web.window.history.pushState(state, '', _hashUrl(currentPath));
    return;
  }
  // Unexpected URL — still ensure current is correct with parent underneath.
  final state = web.window.history.state;
  safeHistoryReplaceUrl(_hashUrl(parentPath));
  web.window.history.pushState(state, '', _hashUrl(currentPath));
}
