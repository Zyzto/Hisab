import 'package:flutter/widgets.dart';

import 'ui_perf.dart';

/// Decode bounds for [Image.network] / [Image.memory] to avoid full-res textures.
///
/// On iOS web (CanvasKit + WebKit), uncapped network images are a known GPU
/// memory / jank risk. Caps apply there; other platforms still decode at
/// display size × DPR (not full source resolution).
abstract final class NetworkImageDecode {
  NetworkImageDecode._();

  /// Max decoded edge length on iOS web (px).
  static const int iosWebMaxEdgePx = 1280;

  /// Cache pixels for a square-ish display size in logical pixels.
  static int cachePx(BuildContext context, double logicalPx) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = (logicalPx * dpr).round().clamp(1, 8192);
    if (UiPerf.isWebIos) {
      return px.clamp(1, iosWebMaxEdgePx);
    }
    return px;
  }

  /// Width/height pair for a box of [logicalWidth] × [logicalHeight].
  static ({int? width, int? height}) cacheSize(
    BuildContext context, {
    double? logicalWidth,
    double? logicalHeight,
  }) {
    return (
      width: logicalWidth == null ? null : cachePx(context, logicalWidth),
      height: logicalHeight == null ? null : cachePx(context, logicalHeight),
    );
  }
}
