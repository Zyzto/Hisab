/// Non-web: no browser location to read.
Uri? browserLocationUri() => null;

/// Non-web: no history API.
void safeHistoryReplaceUrl(String url) {}

/// Non-web: nothing to sanitize.
void sanitizeHashStrategyBrowserUrl() {}

/// Non-web: no address bar to update.
void replaceBrowserAppPath(String appPath) {}

/// Non-web: no browser history to seed.
void seedParentBrowserHistory({
  required String parentPath,
  required String currentPath,
}) {}
