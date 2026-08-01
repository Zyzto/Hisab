/// Pure policy for [UiPerf] — unit-tested without platform channels.
///
/// Inputs are already-resolved surface flags (web + OS + form factor).
class UiPerfPolicy {
  const UiPerfPolicy({
    required this.isWebIos,
    required this.isWebAndroid,
    required this.isWebMobile,
    required this.isNativeIos,
    required this.isNativeAndroid,
  });

  final bool isWebIos;
  final bool isWebAndroid;
  final bool isWebMobile;
  final bool isNativeIos;
  final bool isNativeAndroid;

  /// iOS WebKit only.
  bool get preferCheapShadows => isWebIos;

  /// iOS WebKit only.
  bool get preferInstantShellTabs => isWebIos;

  /// Any mobile browser (coarse pointer).
  bool get preferCheapCharts => isWebMobile;

  /// iOS WebKit only.
  bool get preferFadeOnlyPageTransitions => isWebIos;

  /// Skip looping chrome demos (language pulse, theme cycle, hint ticker).
  /// iOS WebKit only — those timers force rebuilds every few seconds.
  bool get preferReducedChromeMotion => isWebIos;

  /// Home custom-order drag: skip dual-blur feedback, rotate/scale, and
  /// Opacity placeholders that jank CanvasKit on iOS WebKit.
  bool get preferCheapListDrag => isWebIos;
}
