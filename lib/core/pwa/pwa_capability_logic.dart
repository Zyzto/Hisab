import 'pwa_install_mode.dart';

export 'pwa_install_mode.dart';

/// Pure resolution of install UX mode from capability flags.
PwaInstallMode resolvePwaInstallMode({
  required bool isStandalone,
  required bool isMobile,
  required bool canPromptInstall,
  required bool isIos,
  required bool isAndroid,
}) {
  if (isStandalone) return PwaInstallMode.alreadyInstalled;
  if (!isMobile) return PwaInstallMode.unsupported;
  if (canPromptInstall) return PwaInstallMode.nativePrompt;
  if (isIos) return PwaInstallMode.manualIos;
  if (isAndroid) return PwaInstallMode.manualAndroid;
  return PwaInstallMode.manualAndroid;
}

/// Pure resolution of web notification support from capability flags.
PwaNotificationSupport resolvePwaNotificationSupport({
  required bool notificationApiAvailable,
  required bool isIos,
  required bool isStandalone,
}) {
  if (!notificationApiAvailable) return PwaNotificationSupport.unsupported;
  if (isIos && !isStandalone) return PwaNotificationSupport.needsInstall;
  return PwaNotificationSupport.supported;
}

/// Whether the install guide should use iOS Share → Add to Home Screen copy.
bool useIosInstallGuide({required PwaInstallMode mode, required bool isIos}) {
  return mode == PwaInstallMode.manualIos || isIos;
}
