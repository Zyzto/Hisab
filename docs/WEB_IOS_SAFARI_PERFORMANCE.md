# Web and iOS Safari performance

Flutter web surfaces have different rendering budgets on iOS WebKit, Android
Chrome, and desktop browsers. The local-only app keeps the web shell small and
uses the local SQLite worker.

## Current policy

- Keep semantics disabled by default; accessibility builds may opt in with
  ENABLE_WEB_SEMANTICS=true.
- Prefer sliver lists and RepaintBoundary for long local lists.
- Avoid large blur layers and full-tree opacity transitions on mobile web.
- Keep local image decode sizes bounded by their display size.
- Use the 1.5 second fingerprinted database poll on web to avoid rebuilds.

## Local database assets

Web builds require web/sqlite3.wasm and web/powersync_db.worker.js. Recreate
them with:

    flutter pub run powersync:setup_web

## Verification

Test home scrolling, settings navigation, group tabs, receipt attachment, and
backup import on an iOS Safari PWA, Android Chrome, and a desktop browser.
