import 'package:flutter/foundation.dart';

import '../pwa/pwa_capabilities.dart';
import 'ui_perf_logic.dart';

export 'ui_perf_logic.dart';

/// Per-platform UI performance preferences.
///
/// Each surface gets its own budget — do **not** treat “web” as one target:
/// - **iOS web (Safari/WebKit PWA):** weakest GPU/compositor path for Flutter
///   CanvasKit; large shadows, Opacity crossfades, and chart touch layers jank.
/// - **Android web (Chrome):** fuller motion/shadows; still prefer builder lists
///   and avoid chart-touch-vs-scroll fights on phones.
/// - **Desktop web:** full visual polish.
/// - **Native iOS / Android:** full polish (OS compositors handle elevation).
///
/// Unconditional wins (sliver lists, [RepaintBoundary], async Firebase boot)
/// stay outside this class — they help every platform.
///
/// See [docs/WEB_IOS_SAFARI_PERFORMANCE.md].
abstract final class UiPerf {
  UiPerf._();

  static bool get isWeb => kIsWeb;

  /// iPhone / iPad / iPod Safari (incl. Add to Home Screen). All iOS browsers
  /// use WebKit.
  static bool get isWebIos => kIsWeb && isPwaIos;

  static bool get isWebAndroid => kIsWeb && isPwaAndroid;

  /// Coarse-pointer mobile browsers (iOS + Android + similar).
  static bool get isWebMobile => kIsWeb && isPwaMobile;

  static bool get isNativeIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isNativeAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static UiPerfPolicy get _policy => UiPerfPolicy(
    isWebIos: isWebIos,
    isWebAndroid: isWebAndroid,
    isWebMobile: isWebMobile,
    isNativeIos: isNativeIos,
    isNativeAndroid: isNativeAndroid,
  );

  /// Large blurRadius BoxShadows are costly on iOS WebKit GPUs (e.g. XR).
  /// Native and Android Chrome keep the fuller floating-nav look.
  static bool get preferCheapShadows => _policy.preferCheapShadows;

  /// Opacity shell-tab crossfade paints Home + Settings together — janks on
  /// iOS web only. Android web / native keep the crossfade.
  static bool get preferInstantShellTabs => _policy.preferInstantShellTabs;

  /// fl_chart touch tooltips compete with scroll on mobile browsers.
  /// Desktop web and native keep interactive tooltips.
  static bool get preferCheapCharts => _policy.preferCheapCharts;

  /// Fade-only Material page transitions on iOS web (skip slide + opacity).
  static bool get preferFadeOnlyPageTransitions =>
      _policy.preferFadeOnlyPageTransitions;

  /// Skip looping onboarding chrome demos (pulse / theme cycle / hint ticker).
  static bool get preferReducedChromeMotion =>
      _policy.preferReducedChromeMotion;

  /// Home list long-press reorder: cheaper feedback / placeholders on iOS web.
  static bool get preferCheapListDrag => _policy.preferCheapListDrag;
}
