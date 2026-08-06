import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:web/web.dart' as web;

import 'pwa_capability_logic.dart';

export 'pwa_capability_logic.dart';

final List<void Function()> _listeners = [];
bool _jsBridgeWired = false;

@JS('hisabPwa')
external JSObject? get _hisabPwa;

void _ensureJsBridge() {
  if (_jsBridgeWired) return;
  final api = _hisabPwa;
  if (api == null) return;
  _jsBridgeWired = true;
  api.setProperty(
    'onChanged'.toJS,
    (() {
      for (final listener in List<void Function()>.of(_listeners)) {
        listener();
      }
    }).toJS,
  );
}

bool _boolFromApi(String key, {bool fallback = false}) {
  _ensureJsBridge();
  final api = _hisabPwa;
  if (api == null) return fallback;
  final value = api.getProperty(key.toJS);
  if (value == null || value.isUndefinedOrNull) return fallback;
  return (value as JSBoolean).toDart;
}

String _ua() => web.window.navigator.userAgent.toLowerCase();

/// True when launched as installed PWA / TWA / standalone display mode.
bool get isPwaStandalone {
  if (_boolFromApi('isStandalone')) return true;
  try {
    final nav = web.window.navigator as JSObject;
    final standalone = nav.getProperty('standalone'.toJS);
    if (standalone != null &&
        !standalone.isUndefinedOrNull &&
        (standalone as JSBoolean).toDart) {
      return true;
    }
  } catch (e) {
    Log.debug('iOS standalone probe failed', error: e);
  }
  return web.window.matchMedia('(display-mode: standalone)').matches ||
      web.window.matchMedia('(display-mode: fullscreen)').matches ||
      web.window.matchMedia('(display-mode: minimal-ui)').matches;
}

bool get isPwaIos {
  final ua = _ua();
  final iDevice =
      ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  // iPadOS 13+ may report as Macintosh with touch.
  final iPadOsDesktopUa =
      ua.contains('macintosh') && web.window.navigator.maxTouchPoints > 1;
  return iDevice || iPadOsDesktopUa;
}

bool get isPwaAndroid => _ua().contains('android');

bool get isPwaMobile {
  if (isPwaIos || isPwaAndroid) return true;
  try {
    return web.window.matchMedia('(hover: none) and (pointer: coarse)').matches;
  } catch (_) {
    return false;
  }
}

bool get canPromptPwaInstall => _boolFromApi('canPrompt');

PwaInstallMode get pwaInstallMode => resolvePwaInstallMode(
  isStandalone: isPwaStandalone,
  isMobile: isPwaMobile,
  canPromptInstall: canPromptPwaInstall,
  isIos: isPwaIos,
  isAndroid: isPwaAndroid,
);

PwaNotificationSupport get pwaNotificationSupport {
  var notificationApiAvailable = false;
  try {
    // Throws if Notification is unavailable in this browser.
    final _ = web.Notification.permission;
    notificationApiAvailable = true;
  } catch (_) {
    notificationApiAvailable = false;
  }

  return resolvePwaNotificationSupport(
    notificationApiAvailable: notificationApiAvailable,
    isIos: isPwaIos,
    isStandalone: isPwaStandalone,
  );
}

Future<bool> promptPwaInstall() async {
  _ensureJsBridge();
  final api = _hisabPwa;
  if (api == null) return false;
  final fn = api.getProperty('promptInstall'.toJS);
  if (fn == null || fn.isUndefinedOrNull) return false;
  try {
    final result = (fn as JSFunction).callAsFunction(api);
    if (result == null || result.isUndefinedOrNull) return false;
    // hisabPwa.promptInstall always returns a Promise<boolean>.
    final settled = await (result as JSPromise).toDart;
    if (settled == null || settled.isUndefinedOrNull) return false;
    return (settled as JSBoolean).toDart;
  } catch (_) {
    return false;
  }
}

void addPwaCapabilityListener(void Function() listener) {
  _ensureJsBridge();
  _listeners.add(listener);
}

void removePwaCapabilityListener(void Function() listener) {
  _listeners.remove(listener);
}
