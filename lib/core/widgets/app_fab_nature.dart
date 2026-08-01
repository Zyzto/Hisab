import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AppFabPlantKind { flower, sunflower, dandelion }

class AppFabLeafSpec {
  const AppFabLeafSpec({
    required this.angle,
    required this.distance,
    required this.spin,
    required this.delay,
    required this.color,
    required this.size,
  });

  final double angle;
  final double distance;
  final double spin;
  final double delay;
  final Color color;
  final double size;
}

/// Bloom timeline fractions for a ~12s controller (≈0.9s grow, 10s stay, ≈1.1s leave).
abstract final class AppFabBloomTimeline {
  static const double growEnd = 0.075;
  static const double stayEnd = 0.908;
}

/// Canvas leaves / plants for [AppFab]. Alphas are painted directly (no
/// [Opacity] widgets) to keep compositing cheaper.
class AppFabNaturePainter extends CustomPainter {
  AppFabNaturePainter({
    required this.leafProgress,
    required this.leaves,
    required this.bloomProgress,
    required this.plantKind,
  });

  final double leafProgress;
  final List<AppFabLeafSpec> leaves;
  final double bloomProgress;
  final AppFabPlantKind? plantKind;

  static const Size paintSize = Size(140, 160);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2 + 8);
    if (leafProgress > 0 && leaves.isNotEmpty) {
      _paintLeaves(canvas, origin);
    }
    if (bloomProgress > 0 && plantKind != null) {
      _paintBloomScene(canvas, size, origin, plantKind!);
    }
  }

  void _paintLeaves(Canvas canvas, Offset origin) {
    for (final leaf in leaves) {
      final local = ((leafProgress - leaf.delay) / (1.0 - leaf.delay))
          .clamp(0.0, 1.0);
      if (local <= 0) continue;
      final ease = Curves.easeOutCubic.transform(local);
      final fade = (1.0 - Curves.easeIn.transform(local)).clamp(0.0, 1.0);
      final dist = leaf.distance * ease;
      final pos =
          origin + Offset(math.cos(leaf.angle), math.sin(leaf.angle)) * dist;
      final rot = leaf.angle + leaf.spin * ease;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rot);
      final paint = Paint()
        ..color = leaf.color.withValues(alpha: 0.85 * fade)
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(0, -leaf.size)
        ..quadraticBezierTo(leaf.size * 0.7, -leaf.size * 0.2, 0, leaf.size)
        ..quadraticBezierTo(-leaf.size * 0.7, -leaf.size * 0.2, 0, -leaf.size)
        ..close();
      canvas.drawPath(path, paint);
      final vein = Paint()
        ..color = Colors.black.withValues(alpha: 0.12 * fade)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, -leaf.size * 0.7),
        Offset(0, leaf.size * 0.6),
        vein,
      );
      canvas.restore();
    }
  }

  void _paintBloomScene(
    Canvas canvas,
    Size size,
    Offset origin,
    AppFabPlantKind kind,
  ) {
    final t = bloomProgress.clamp(0.0, 1.0);
    final growT = (t / AppFabBloomTimeline.growEnd).clamp(0.0, 1.0);
    final grow = Curves.easeOutBack.transform(growT);

    final inStay = t >= AppFabBloomTimeline.growEnd &&
        t < AppFabBloomTimeline.stayEnd;
    final leaving = t >= AppFabBloomTimeline.stayEnd;
    final leaveT = leaving
        ? ((t - AppFabBloomTimeline.stayEnd) /
                (1.0 - AppFabBloomTimeline.stayEnd))
            .clamp(0.0, 1.0)
        : 0.0;

    final sceneFade = leaving
        ? (1.0 - Curves.easeIn.transform(leaveT)).clamp(0.0, 1.0)
        : Curves.easeOut.transform(growT.clamp(0.0, 1.0));
    final float = leaving ? Curves.easeIn.transform(leaveT) : 0.0;

    // Multi-frequency wind: slow breeze + quicker gusts while staying.
    final windStrength = (inStay || leaving ? 1.0 : grow) * sceneFade;
    final sway = (math.sin(t * math.pi * 18) * 0.14 +
            math.sin(t * math.pi * 7.5 + 0.8) * 0.08 +
            math.sin(t * math.pi * 3.2) * 0.05) *
        windStrength;

    _paintSoftGlow(canvas, origin, t, sceneFade);
    _paintWind(canvas, size, origin, t, sceneFade);

    final base = origin + Offset(sway * 14, -10 - 40 * grow - 48 * float);
    final scale = 0.25 + 0.75 * grow;

    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(scale);
    // Stem bends with wind; tip lags a bit for a soft plant feel.
    canvas.rotate(sway * 1.15);

    switch (kind) {
      case AppFabPlantKind.flower:
        _drawFlower(canvas, sceneFade, sway);
      case AppFabPlantKind.sunflower:
        _drawSunflower(canvas, sceneFade, sway);
      case AppFabPlantKind.dandelion:
        _drawDandelion(canvas, sceneFade, t, leaveT, leaving);
    }
    canvas.restore();
  }

  /// Soft ambient glow only — no hard sun beams / rays.
  void _paintSoftGlow(Canvas canvas, Offset origin, double t, double fade) {
    if (fade <= 0) return;
    final pulse = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(t * math.pi * 3));
    final alpha = 0.12 * fade * pulse;
    final center = Offset(origin.dx - 8, origin.dy - 36);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF59D).withValues(alpha: alpha),
          const Color(0xFFFFF59D).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 56));
    canvas.drawCircle(center, 56, glow);
  }

  void _paintWind(
    Canvas canvas,
    Size size,
    Offset origin,
    double t,
    double fade,
  ) {
    if (fade <= 0) return;
    final windPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;

    for (var i = 0; i < 4; i++) {
      final phase = (t * 2.2 + i * 0.27) % 1.0;
      final y = origin.dy - 48 + i * 14.0 + math.sin(t * math.pi * 6 + i) * 3;
      final x0 = origin.dx - 55 + phase * 110;
      final alpha =
          (0.18 * fade * math.sin(phase * math.pi)).clamp(0.0, 0.22);
      windPaint.color = Colors.white.withValues(alpha: alpha);
      final path = Path()
        ..moveTo(x0, y)
        ..quadraticBezierTo(x0 + 12, y - 4, x0 + 24, y + 1)
        ..quadraticBezierTo(x0 + 34, y + 4, x0 + 42, y);
      canvas.drawPath(path, windPaint);
    }

    // Tiny wind motes drifting with the breeze.
    final mote = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 6; i++) {
      final phase = (t * 1.6 + i * 0.17) % 1.0;
      final x = origin.dx - 50 + phase * 100;
      final y = origin.dy - 40 + (i * 9) + math.sin(t * 10 + i) * 5;
      mote.color = Colors.white.withValues(
        alpha: 0.2 * fade * math.sin(phase * math.pi),
      );
      canvas.drawCircle(Offset(x, y), 1.2, mote);
    }
  }

  void _drawStem(Canvas canvas, double fade, {double length = 22}) {
    final stem = Paint()
      ..color = const Color(0xFF4CAF50).withValues(alpha: 0.9 * fade)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Slight curve in the stem from wind.
    final path = Path()
      ..moveTo(0, length)
      ..quadraticBezierTo(3.5, length * 0.45, 0, 0);
    canvas.drawPath(path, stem);
  }

  void _drawFlower(Canvas canvas, double fade, double sway) {
    _drawStem(canvas, fade);
    const petalCount = 6;
    final petalPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < petalCount; i++) {
      canvas.save();
      canvas.rotate(i * math.pi * 2 / petalCount + sway * 0.15);
      petalPaint.color = const Color(0xFFFF80AB).withValues(alpha: 0.9 * fade);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -9), width: 8, height: 12),
        petalPaint,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      Offset.zero,
      4.5,
      Paint()..color = const Color(0xFFFFF176).withValues(alpha: 0.95 * fade),
    );
  }

  void _drawSunflower(Canvas canvas, double fade, double sway) {
    _drawStem(canvas, fade, length: 24);
    const petalCount = 10;
    final petalPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < petalCount; i++) {
      canvas.save();
      canvas.rotate(i * math.pi * 2 / petalCount + sway * 0.1);
      petalPaint.color = const Color(0xFFFFD54F).withValues(alpha: 0.92 * fade);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -11), width: 7, height: 14),
        petalPaint,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      Offset.zero,
      6.5,
      Paint()..color = const Color(0xFF6D4C41).withValues(alpha: 0.95 * fade),
    );
    canvas.drawCircle(
      Offset.zero,
      3.5,
      Paint()..color = const Color(0xFF4E342E).withValues(alpha: 0.9 * fade),
    );
  }

  void _drawDandelion(
    Canvas canvas,
    double fade,
    double t,
    double leaveT,
    bool leaving,
  ) {
    _drawStem(canvas, fade, length: 26);
    final puff = Paint()
      ..color = Colors.white.withValues(alpha: 0.88 * fade)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 9, puff);
    final seed = Paint()
      ..color = const Color(0xFFE0E0E0).withValues(alpha: 0.75 * fade)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi * 2 / 12 + t * 2.4;
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(a) * 9, math.sin(a) * 9),
        seed,
      );
    }
    // Seeds blow away on the wind when leaving (and a few during late stay).
    if (leaving || t > AppFabBloomTimeline.stayEnd - 0.04) {
      final drift = leaving ? leaveT : 0.15;
      final seedFill = Paint()
        ..color = Colors.white.withValues(alpha: 0.7 * fade * (1 - drift));
      for (var i = 0; i < 6; i++) {
        final a = -1.0 + i * 0.28;
        canvas.drawCircle(
          Offset(
            math.cos(a) * (12 + 36 * drift) + t * 8,
            -8 - 22 * drift - i * 2.5,
          ),
          1.5,
          seedFill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant AppFabNaturePainter oldDelegate) {
    return oldDelegate.leafProgress != leafProgress ||
        oldDelegate.bloomProgress != bloomProgress ||
        oldDelegate.plantKind != plantKind ||
        oldDelegate.leaves != leaves;
  }
}

List<AppFabLeafSpec> generateAppFabLeaves(math.Random rng) {
  const greens = <Color>[
    Color(0xFF66BB6A),
    Color(0xFF43A047),
    Color(0xFF81C784),
    Color(0xFF2E7D32),
    Color(0xFFA5D6A7),
  ];
  final count = 5 + rng.nextInt(3);
  return List<AppFabLeafSpec>.generate(count, (i) {
    final spread = (i / count) * math.pi * 2 + rng.nextDouble() * 0.4;
    return AppFabLeafSpec(
      angle: spread - math.pi / 2 + (rng.nextDouble() - 0.5) * 0.8,
      distance: 36 + rng.nextDouble() * 28,
      spin: (rng.nextDouble() - 0.5) * 3.2,
      delay: rng.nextDouble() * 0.18,
      color: greens[rng.nextInt(greens.length)],
      size: 5.5 + rng.nextDouble() * 3.5,
    );
  });
}
