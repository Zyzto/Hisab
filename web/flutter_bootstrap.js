// Custom Flutter web bootstrap.
// Intentionally avoids passing deprecated default service-worker settings.
// Firebase messaging service worker (web/firebase-messaging-sw.js) is handled
// by firebase_messaging when configured in app code.

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();
