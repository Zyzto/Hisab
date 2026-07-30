// Custom Flutter web bootstrap.
// Intentionally avoids passing deprecated default service-worker settings.
// Firebase messaging service worker (web/firebase-messaging-sw.js) is handled
// by firebase_messaging when configured in app code.
// Wait for async Firebase init from index.html so messaging sees a ready app.

{{flutter_js}}
{{flutter_build_config}}

Promise.resolve(window.__hisabFirebaseReady)
  .catch(function () {})
  .then(function () {
    _flutter.loader.load();
  });
