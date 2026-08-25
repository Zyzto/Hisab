import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Circular reveal from the theme chip.
const Duration kOnboardingThemeRippleDuration = Duration(milliseconds: 1000);

/// Cheaper one-shot on iOS web.
const Duration kOnboardingThemeRippleCheapDuration = Duration(
  milliseconds: 750,
);

const Color kOnboardingThemeLightFill = Color(0xFFF5E6C8);
const Color kOnboardingThemeDarkFill = Color(0xFF37474F);
const Color kOnboardingThemeAmoledFill = Color(0xFF000000);
const Color kOnboardingThemeLightIcon = Color(0xFF5D4037);
const Color kOnboardingThemeDarkIcon = Color(0xFFECEFF1);

/// Circle large enough to cover [size] from [origin].
@visibleForTesting
double themeRippleMaxRadius(Size size, Offset origin) {
  final corners = <Offset>[
    Offset.zero,
    Offset(size.width, 0),
    Offset(0, size.height),
    Offset(size.width, size.height),
  ];
  var maxDistance = 0.0;
  for (final corner in corners) {
    final distance = (corner - origin).distance;
    if (distance > maxDistance) maxDistance = distance;
  }
  return maxDistance;
}

/// Hole / wash radius for a 0–1 controller value.
@visibleForTesting
double themeRippleRadiusAt(Size size, Offset origin, double progress) {
  final maxRadius = themeRippleMaxRadius(size, origin);
  if (maxRadius <= 0) return 0;
  return maxRadius * Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
}

/// Fill that matches the onboarding theme chip so the wash grows out of it.
Color themeRippleFillForMode(
  String theme, {
  required Brightness platformBrightness,
}) {
  switch (theme) {
    case 'light':
      return kOnboardingThemeLightFill;
    case 'dark':
      return kOnboardingThemeDarkFill;
    case 'amoled':
      return kOnboardingThemeAmoledFill;
    case 'system':
    default:
      return platformBrightness == Brightness.dark
          ? kOnboardingThemeDarkFill
          : kOnboardingThemeLightFill;
  }
}

/// Ring stroke that stays readable on [themeRippleFillForMode].
Color themeRippleRingForMode(
  String theme, {
  required Brightness platformBrightness,
}) {
  final darkFill =
      theme == 'dark' ||
      theme == 'amoled' ||
      (theme == 'system' && platformBrightness == Brightness.dark);
  return darkFill ? kOnboardingThemeDarkIcon : kOnboardingThemeLightIcon;
}

/// Growing hole through the previous chrome frame, revealing the live theme.
class OnboardingThemeRipple extends StatelessWidget {
  const OnboardingThemeRipple({
    super.key,
    required this.animation,
    required this.origin,
    this.snapshot,
  });

  final Animation<double> animation;
  final Offset origin;
  final ui.Image? snapshot;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          if (snapshot == null) return const SizedBox.expand();
          return ClipPath(
            clipBehavior: Clip.antiAlias,
            clipper: ThemeRippleRevealClipper(
              origin: origin,
              progress: animation.value,
            ),
            child: RawImage(image: snapshot, fit: BoxFit.fill),
          );
        },
      ),
    );
  }
}

/// Keeps the old frame except for an expanding circle around [origin].
class ThemeRippleRevealClipper extends CustomClipper<Path> {
  ThemeRippleRevealClipper({required this.origin, required this.progress});

  final Offset origin;
  final double progress;

  @override
  Path getClip(Size size) {
    final holeRadius = themeRippleRadiusAt(size, origin, progress);
    final rect = Path()..addRect(Offset.zero & size);
    if (holeRadius <= 0) return rect;
    final hole = Path()
      ..addOval(Rect.fromCircle(center: origin, radius: holeRadius));
    return Path.combine(PathOperation.difference, rect, hole);
  }

  @override
  bool shouldReclip(covariant ThemeRippleRevealClipper oldClipper) {
    return oldClipper.origin != origin || oldClipper.progress != progress;
  }
}

/// Raster of a [RepaintBoundary], or null if the layer is not ready.
Future<ui.Image?> themeRippleCaptureBoundary(
  GlobalKey key, {
  required double pixelRatio,
}) async {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary || !boundary.hasSize) {
    return null;
  }
  try {
    if (boundary.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
    }
    return await boundary.toImage(pixelRatio: pixelRatio.clamp(1.0, 2.0));
  } catch (_) {
    return null;
  }
}

/// Maps a chip center in [button] into the ripple host's local space.
Offset themeRippleOriginForButton({
  required RenderBox? button,
  required RenderBox? host,
}) {
  if (host == null || !host.hasSize) {
    return Offset.zero;
  }
  if (button == null || !button.hasSize) {
    return host.size.center(Offset.zero);
  }
  return host.globalToLocal(
    button.localToGlobal(button.size.center(Offset.zero)),
  );
}
