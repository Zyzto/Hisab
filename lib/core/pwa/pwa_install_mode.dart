/// How the user can install the web app on the current device/browser.
enum PwaInstallMode {
  /// Already running as an installed PWA / TWA / standalone.
  alreadyInstalled,

  /// Chromium-style deferred `beforeinstallprompt` is available.
  nativePrompt,

  /// iPhone/iPad: Share → Add to Home Screen.
  manualIos,

  /// Android (or other) without a native prompt: browser menu install.
  manualAndroid,

  /// Desktop / unsupported — do not show install UI.
  unsupported,
}
