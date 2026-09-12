import 'pwa_capability_logic.dart';

export 'pwa_capability_logic.dart';

/// Non-web defaults: no install banner is needed.
bool get isPwaStandalone => true;

bool get isPwaIos => false;

bool get isPwaAndroid => false;

bool get isPwaMobile => false;

bool get canPromptPwaInstall => false;

PwaInstallMode get pwaInstallMode => resolvePwaInstallMode(
  isStandalone: isPwaStandalone,
  isMobile: isPwaMobile,
  canPromptInstall: canPromptPwaInstall,
  isIos: isPwaIos,
  isAndroid: isPwaAndroid,
);

/// No-op outside web.
Future<bool> promptPwaInstall() async => false;

/// No-op outside web.
void addPwaCapabilityListener(void Function() listener) {}

/// No-op outside web.
void removePwaCapabilityListener(void Function() listener) {}
