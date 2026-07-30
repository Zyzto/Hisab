import 'package:flutter/material.dart';

import '../layout/layout_breakpoints.dart';
import '../platform/ui_perf.dart';

/// Shared navigation / modal motion tokens and builders.
///
/// Unrelated UI chrome may still use [ThemeConfig] animation durations.
class AppMotion {
  AppMotion._();

  /// Hierarchical page push/pop and expense-detail enter/paging.
  static const Duration page = Duration(milliseconds: 280);

  /// Shell home ↔ settings IndexedStack crossfade (matches FloatingNavBar).
  static const Duration shellTab = Duration(milliseconds: 200);

  /// Sheets, dialogs, and adaptive sheet↔dialog morph.
  static const Duration modal = Duration(milliseconds: 320);

  /// Permanent sidenav width morph.
  static const Duration shellNav = LayoutBreakpoints.shellNavMorphDuration;

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;

  /// Horizontal slide distance as a fraction of width (fade+slide pages).
  static const double pageSlideFraction = 0.04;

  /// Narrow sheet slide-up distance in logical pixels.
  static const double sheetSlideUpPx = 56.0;

  /// Wide sheet / dialog start scale.
  static const double dialogStartScale = 0.96;

  /// Fade + short end-slide. [animation] is the primary route animation (0→1).
  /// Respects [TextDirection] so RTL slides from the start edge.
  ///
  /// Uses [Animatable.drive] (no owned [CurvedAnimation]). Reverse uses
  /// [exitCurve] via status-aware transform.
  static Widget buildFadeSlideTransition({
    required Animation<double> animation,
    required Widget child,
    required TextDirection direction,
    double slideFraction = pageSlideFraction,
  }) {
    final curved = animation.drive(_StatusAwareCurveTween(animation));
    final beginDx = direction == TextDirection.rtl
        ? -slideFraction
        : slideFraction;
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(beginDx, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  /// Fade + scale (wide sheet / dialog entrance).
  static Widget buildFadeScaleTransition({
    required Animation<double> animation,
    required Widget child,
    double beginScale = dialogStartScale,
  }) {
    final t = enterCurve.transform(animation.value.clamp(0.0, 1.0));
    final scale = beginScale + ((1.0 - beginScale) * t);
    return Opacity(
      opacity: t,
      child: Transform.scale(scale: scale, child: child),
    );
  }

  /// Fade + slide up (narrow bottom sheet entrance).
  static Widget buildSlideUpTransition({
    required Animation<double> animation,
    required Widget child,
    double slidePx = sheetSlideUpPx,
  }) {
    final t = enterCurve.transform(animation.value.clamp(0.0, 1.0));
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * slidePx),
        child: child,
      ),
    );
  }

  /// Fade only (fullscreen image dialogs).
  static Widget buildFadeTransition({
    required Animation<double> animation,
    required Widget child,
  }) {
    final t = enterCurve.transform(animation.value.clamp(0.0, 1.0));
    return Opacity(opacity: t, child: child);
  }
}

/// Applies [AppMotion.enterCurve] forward and [AppMotion.exitCurve] in reverse.
class _StatusAwareCurveTween extends Animatable<double> {
  const _StatusAwareCurveTween(this.animation);

  final Animation<double> animation;

  @override
  double transform(double t) {
    final reversing = animation.status == AnimationStatus.reverse;
    if (reversing) {
      return 1.0 - AppMotion.exitCurve.transform(1.0 - t);
    }
    return AppMotion.enterCurve.transform(t);
  }
}

/// Platform page transitions matching [AppMotion.buildFadeSlideTransition].
class AppFadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const AppFadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // iOS web only: slide + opacity compositing is costly on WebKit / older GPUs.
    if (UiPerf.preferFadeOnlyPageTransitions) {
      return AppMotion.buildFadeTransition(
        animation: animation,
        child: child,
      );
    }
    return AppMotion.buildFadeSlideTransition(
      animation: animation,
      child: child,
      direction: Directionality.of(context),
    );
  }
}

/// Shared [PageTransitionsTheme] for Material routes (scanner stack, etc.).
PageTransitionsTheme appPageTransitionsTheme() {
  const builder = AppFadeSlidePageTransitionsBuilder();
  return const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: builder,
      TargetPlatform.iOS: builder,
      TargetPlatform.macOS: builder,
      TargetPlatform.windows: builder,
      TargetPlatform.linux: builder,
      TargetPlatform.fuchsia: builder,
    },
  );
}
