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

  /// Bottom-sheet paper-roll open/close (camera, QR scanner).
  static const Duration sheetRoll = Duration(milliseconds: 420);

  /// Permanent sidenav width morph.
  static const Duration shellNav = LayoutBreakpoints.shellNavMorphDuration;

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;

  /// Soft ease-out with a light settle (clamped to 0–1 by the roll builder).
  static const Curve sheetRollEnter = Cubic(0.18, 0.7, 0.2, 1.0);

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
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = enterCurve.transform(animation.value.clamp(0.0, 1.0));
        final scale = beginScale + ((1.0 - beginScale) * t);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: child,
    );
  }

  /// Fade + slide up (narrow bottom sheet entrance).
  static Widget buildSlideUpTransition({
    required Animation<double> animation,
    required Widget child,
    double slidePx = sheetSlideUpPx,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = enterCurve.transform(animation.value.clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * slidePx),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Bottom sheet paper-roll: panel grows upward from the screen bottom.
  ///
  /// [child] must be tight-sized (explicit height). Uses top-aligned clipping
  /// so the drag handle leads as the sheet unrolls (not the footer first).
  static Widget buildBottomSheetReboundTransition({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        final reversing = animation.status == AnimationStatus.reverse;
        final factor = reversing
            ? exitCurve.transform(t)
            : sheetRollEnter.transform(t);
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: factor.clamp(0.0, 1.0),
            widthFactor: 1.0,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Fade only (fullscreen image dialogs).
  static Widget buildFadeTransition({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = enterCurve.transform(animation.value.clamp(0.0, 1.0));
        return Opacity(opacity: t, child: child);
      },
      child: child,
    );
  }

  /// Genie-bottle open: smoke-puff + scale out from the FAB corner (bottom end).
  ///
  /// [origin] is optional — used for the smoke puff position. Scale pivots from
  /// [scaleAlignment] (default bottom-end, where the scan FAB lives).
  static Widget buildGenieBottleTransition({
    required Animation<double> animation,
    required Widget child,
    Rect? origin,
    AlignmentGeometry scaleAlignment = AlignmentDirectional.bottomEnd,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        final curved = enterCurve.transform(t);
        final scaleT = Curves.easeOutBack.transform(curved.clamp(0.0, 1.0));
        final opacity = Curves.easeOut.transform((t * 1.4).clamp(0.0, 1.0));
        final scale = (0.06 + 0.94 * scaleT).clamp(0.06, 1.12);
        final rise = (1 - curved) * 28;

        final fab =
            origin ??
            Rect.fromLTWH(
              MediaQuery.sizeOf(context).width - 72,
              MediaQuery.sizeOf(context).height - 96,
              56,
              56,
            );

        return Stack(
          fit: StackFit.expand,
          children: [
            if (t < 0.6)
              Positioned(
                left: fab.center.dx - 32 * (1 + t * 2.2),
                top: fab.center.dy - 40 * (1 + t * 2.8) - curved * 90,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (0.4 * (1 - t / 0.6)).clamp(0.0, 0.4),
                    child: Container(
                      width: 64 * (1 + t * 2.8),
                      height: 64 * (1 + t * 2.8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.4),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, rise),
                child: Transform.scale(
                  scale: scale,
                  alignment: scaleAlignment.resolve(Directionality.of(context)),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
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
      return AppMotion.buildFadeTransition(animation: animation, child: child);
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
