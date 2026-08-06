import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AppFabPlantKind {
  flower,
  sunflower,
  dandelion,
  tulip,
  daisy,
  lavender,
  rose,
  bluebell,
}

/// Classic single-plant blooms (pre-bouquet set).
const List<AppFabPlantKind> appFabOriginalPlantKinds = [
  AppFabPlantKind.flower,
  AppFabPlantKind.sunflower,
  AppFabPlantKind.dandelion,
];

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

/// Bloom timeline fractions for a ~6s controller (≈0.45s grow, ~5s stay, ≈0.55s leave).
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
    this.bouquet = false,
  });

  final double leafProgress;
  final List<AppFabLeafSpec> leaves;
  final double bloomProgress;
  final AppFabPlantKind? plantKind;

  /// When true, draw a multi-plant cluster; otherwise a single classic plant.
  final bool bouquet;

  /// Tall canvas so flower heads sit above the FAB; stems root on its top edge.
  static const Size paintSize = Size(168, 220);

  /// Must match the FAB box ([AppFab.size]) and the [Positioned] lift in [AppFab].
  static const double fabSize = 56;
  static const double paintLift = 28;

  /// How far the stem root tucks under the FAB rim (layer is behind the button).
  static const double _stemRootInset = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    // Same transform as AppFab's Positioned nature layer → FAB box mapping.
    final natureTop = (fabSize - size.height) / 2 - paintLift;
    final origin = Offset(size.width / 2, fabSize / 2 - natureTop);
    final fabTopY = -natureTop;
    if (leafProgress > 0 && leaves.isNotEmpty) {
      _paintLeaves(canvas, origin);
    }
    if (bloomProgress > 0 && plantKind != null) {
      _paintBloomScene(canvas, size, origin, fabTopY, plantKind!);
    }
  }

  void _paintLeaves(Canvas canvas, Offset origin) {
    for (final leaf in leaves) {
      final local = ((leafProgress - leaf.delay) / (1.0 - leaf.delay)).clamp(
        0.0,
        1.0,
      );
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
    double fabTopY,
    AppFabPlantKind kind,
  ) {
    final t = bloomProgress.clamp(0.0, 1.0);
    final growT = (t / AppFabBloomTimeline.growEnd).clamp(0.0, 1.0);
    final grow = Curves.easeOutBack.transform(growT);

    final inStay =
        t >= AppFabBloomTimeline.growEnd && t < AppFabBloomTimeline.stayEnd;
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
    final sway =
        (math.sin(t * math.pi * 18) * 0.14 +
            math.sin(t * math.pi * 7.5 + 0.8) * 0.08 +
            math.sin(t * math.pi * 3.2) * 0.05) *
        windStrength;

    _paintSoftGlow(canvas, origin, t, sceneFade);
    _paintWind(canvas, size, origin, t, sceneFade);

    // Plant on the FAB top edge (slightly under the rim — we're behind the button).
    final rootY = fabTopY + _stemRootInset;
    final plants = bouquet ? _bouquetFor(kind) : _classicPlant(kind);
    for (final plant in plants) {
      final localSway = sway * plant.swayMul;
      final scale = (0.22 + 0.78 * grow) * plant.scale;
      final rootX = origin.dx + plant.dx;
      // Pivot at the FAB root so sway never detaches the stem base.
      final root = Offset(rootX, rootY - 52 * float);

      canvas.save();
      canvas.translate(root.dx, root.dy);
      canvas.rotate(localSway * 1.2 + plant.lean);
      canvas.scale(scale);
      canvas.translate(0, -plant.stem);

      switch (plant.kind) {
        case AppFabPlantKind.flower:
          _drawFlower(canvas, sceneFade, localSway, stemLength: plant.stem);
        case AppFabPlantKind.sunflower:
          _drawSunflower(canvas, sceneFade, localSway, stemLength: plant.stem);
        case AppFabPlantKind.dandelion:
          _drawDandelion(
            canvas,
            sceneFade,
            t,
            leaveT,
            leaving,
            stemLength: plant.stem,
          );
        case AppFabPlantKind.tulip:
          _drawTulip(canvas, sceneFade, localSway, stemLength: plant.stem);
        case AppFabPlantKind.daisy:
          _drawDaisy(canvas, sceneFade, localSway, stemLength: plant.stem);
        case AppFabPlantKind.lavender:
          _drawLavender(canvas, sceneFade, localSway, stemLength: plant.stem);
        case AppFabPlantKind.rose:
          _drawRose(canvas, sceneFade, localSway, stemLength: plant.stem);
        case AppFabPlantKind.bluebell:
          _drawBluebell(canvas, sceneFade, localSway, stemLength: plant.stem);
      }
      canvas.restore();
    }
  }

  List<_BloomPlant> _classicPlant(AppFabPlantKind hero) {
    return [
      _BloomPlant(
        kind: hero,
        dx: 0,
        scale: 1.0,
        stem: 28,
        swayMul: 1.0,
        lean: 0,
      ),
    ];
  }

  /// Multi-plant cluster: classic hero plus mixed companions (incl. new kinds).
  List<_BloomPlant> _bouquetFor(AppFabPlantKind hero) {
    final kinds = AppFabPlantKind.values;
    final i = hero.index;
    final sideA = kinds[(i + 1) % kinds.length];
    final sideB = kinds[(i + 3) % kinds.length];
    final sideC = kinds[(i + 5) % kinds.length];
    return [
      _BloomPlant(
        kind: hero,
        dx: 0,
        scale: 1.0,
        stem: 30,
        swayMul: 1.0,
        lean: 0,
      ),
      _BloomPlant(
        kind: sideA,
        dx: -20,
        scale: 0.78,
        stem: 26,
        swayMul: 1.15,
        lean: -0.12,
      ),
      _BloomPlant(
        kind: sideB,
        dx: 18,
        scale: 0.72,
        stem: 24,
        swayMul: 0.9,
        lean: 0.14,
      ),
      _BloomPlant(
        kind: sideC,
        dx: -9,
        scale: 0.58,
        stem: 22,
        swayMul: 1.25,
        lean: -0.06,
      ),
      _BloomPlant(
        kind: sideA,
        dx: 11,
        scale: 0.52,
        stem: 20,
        swayMul: 1.05,
        lean: 0.08,
      ),
    ];
  }

  /// Soft ambient glow only — no hard sun beams / rays.
  void _paintSoftGlow(Canvas canvas, Offset origin, double t, double fade) {
    if (fade <= 0) return;
    final pulse = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(t * math.pi * 3));
    final alpha = 0.12 * fade * pulse;
    final center = Offset(origin.dx - 8, origin.dy - 72);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF59D).withValues(alpha: alpha),
          const Color(0xFFFFF59D).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 72));
    canvas.drawCircle(center, 72, glow);
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

    for (var i = 0; i < 5; i++) {
      final phase = (t * 2.2 + i * 0.27) % 1.0;
      final y = origin.dy - 88 + i * 16.0 + math.sin(t * math.pi * 6 + i) * 3;
      final x0 = origin.dx - 62 + phase * 124;
      final alpha = (0.18 * fade * math.sin(phase * math.pi)).clamp(0.0, 0.22);
      windPaint.color = Colors.white.withValues(alpha: alpha);
      final path = Path()
        ..moveTo(x0, y)
        ..quadraticBezierTo(x0 + 12, y - 4, x0 + 24, y + 1)
        ..quadraticBezierTo(x0 + 34, y + 4, x0 + 42, y);
      canvas.drawPath(path, windPaint);
    }

    // Tiny wind motes drifting with the breeze.
    final mote = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 8; i++) {
      final phase = (t * 1.6 + i * 0.17) % 1.0;
      final x = origin.dx - 56 + phase * 112;
      final y = origin.dy - 78 + (i * 10) + math.sin(t * 10 + i) * 5;
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

    // Pair of small leaves mid-stem so the stalk reads clearly.
    final leafPaint = Paint()
      ..color = const Color(0xFF66BB6A).withValues(alpha: 0.85 * fade)
      ..style = PaintingStyle.fill;
    final mid = length * 0.55;
    canvas.save();
    canvas.translate(-1.5, mid);
    canvas.rotate(-0.7);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 7, height: 3.2),
      leafPaint,
    );
    canvas.restore();
    canvas.save();
    canvas.translate(1.5, mid + 3);
    canvas.rotate(0.75);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 6.5, height: 3),
      leafPaint,
    );
    canvas.restore();
  }

  void _drawFlower(
    Canvas canvas,
    double fade,
    double sway, {
    double stemLength = 28,
  }) {
    _drawStem(canvas, fade, length: stemLength);
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

  void _drawSunflower(
    Canvas canvas,
    double fade,
    double sway, {
    double stemLength = 28,
  }) {
    _drawStem(canvas, fade, length: stemLength);
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
    bool leaving, {
    double stemLength = 28,
  }) {
    _drawStem(canvas, fade, length: stemLength);
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

  void _drawTulip(
    Canvas canvas,
    double fade,
    double sway, {
    double stemLength = 28,
  }) {
    _drawStem(canvas, fade, length: stemLength);
    final petal = Paint()
      ..color = const Color(0xFFE53935).withValues(alpha: 0.92 * fade)
      ..style = PaintingStyle.fill;
    // Cup of three pointed petals.
    for (final dx in [-5.5, 0.0, 5.5]) {
      final path = Path()
        ..moveTo(dx * 0.2, 2)
        ..quadraticBezierTo(dx - 1, -4, dx * 0.35, -13 + sway.abs() * 2)
        ..quadraticBezierTo(dx + 4, -6, dx * 0.15, 2)
        ..close();
      canvas.drawPath(path, petal);
    }
    final inner = Paint()
      ..color = const Color(0xFFFFCDD2).withValues(alpha: 0.55 * fade)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -4), width: 6, height: 8),
      inner,
    );
  }

  void _drawDaisy(
    Canvas canvas,
    double fade,
    double sway, {
    double stemLength = 28,
  }) {
    _drawStem(canvas, fade, length: stemLength);
    const petalCount = 12;
    final petalPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < petalCount; i++) {
      canvas.save();
      canvas.rotate(i * math.pi * 2 / petalCount + sway * 0.08);
      petalPaint.color = Colors.white.withValues(alpha: 0.93 * fade);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -8), width: 4.5, height: 11),
        petalPaint,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      Offset.zero,
      4.8,
      Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: 0.95 * fade),
    );
    canvas.drawCircle(
      Offset.zero,
      2.2,
      Paint()..color = const Color(0xFFFBC02D).withValues(alpha: 0.9 * fade),
    );
  }

  void _drawLavender(
    Canvas canvas,
    double fade,
    double sway, {
    double stemLength = 30,
  }) {
    _drawStem(canvas, fade, length: stemLength);
    final floret = Paint()..style = PaintingStyle.fill;
    // Tall spike of small purple buds.
    for (var row = 0; row < 7; row++) {
      final y = -2.0 - row * 3.2;
      final spread = 3.2 - row * 0.28;
      for (final side in [-1.0, 0.0, 1.0]) {
        if (row > 4 && side == 0) continue;
        floret.color = Color.lerp(
          const Color(0xFF7E57C2),
          const Color(0xFFB39DDB),
          row / 7,
        )!.withValues(alpha: (0.88 - row * 0.04) * fade);
        canvas.drawCircle(
          Offset(side * spread + sway * 1.5, y),
          2.1 - row * 0.12,
          floret,
        );
      }
    }
  }

  void _drawRose(
    Canvas canvas,
    double fade,
    double sway, {
    double stemLength = 28,
  }) {
    _drawStem(canvas, fade, length: stemLength);
    final petal = Paint()..style = PaintingStyle.fill;
    // Layered overlapping ovals for a compact rose head.
    const layers = [
      (r: 9.0, n: 5, c: Color(0xFFC62828)),
      (r: 6.5, n: 5, c: Color(0xFFE53935)),
      (r: 4.0, n: 4, c: Color(0xFFEF5350)),
    ];
    for (final layer in layers) {
      for (var i = 0; i < layer.n; i++) {
        canvas.save();
        canvas.rotate(i * math.pi * 2 / layer.n + sway * 0.1 + layer.r * 0.02);
        petal.color = layer.c.withValues(alpha: 0.9 * fade);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -layer.r * 0.35),
            width: layer.r * 0.85,
            height: layer.r,
          ),
          petal,
        );
        canvas.restore();
      }
    }
    canvas.drawCircle(
      Offset.zero,
      2.4,
      Paint()..color = const Color(0xFFFFCDD2).withValues(alpha: 0.95 * fade),
    );
  }

  void _drawBluebell(
    Canvas canvas,
    double fade,
    double sway, {
    double stemLength = 26,
  }) {
    _drawStem(canvas, fade, length: stemLength);
    final bell = Paint()
      ..color = const Color(0xFF5C6BC0).withValues(alpha: 0.9 * fade)
      ..style = PaintingStyle.fill;
    final rim = Paint()
      ..color = const Color(0xFF9FA8DA).withValues(alpha: 0.85 * fade)
      ..style = PaintingStyle.fill;
    // Cluster of nodding bells along the upper stem.
    const bells = [
      (dx: 0.0, dy: -2.0, s: 1.0),
      (dx: -6.0, dy: 3.0, s: 0.82),
      (dx: 5.5, dy: 5.0, s: 0.75),
      (dx: -3.0, dy: 9.0, s: 0.62),
    ];
    for (final b in bells) {
      canvas.save();
      canvas.translate(b.dx + sway * 2, b.dy);
      canvas.scale(b.s);
      canvas.rotate(0.35 + sway * 0.2);
      final body = Path()
        ..moveTo(-4, -6)
        ..quadraticBezierTo(-5.5, 1, -3.5, 5)
        ..quadraticBezierTo(0, 7, 3.5, 5)
        ..quadraticBezierTo(5.5, 1, 4, -6)
        ..close();
      canvas.drawPath(body, bell);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 5.2), width: 7, height: 2.4),
        rim,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant AppFabNaturePainter oldDelegate) {
    return oldDelegate.leafProgress != leafProgress ||
        oldDelegate.bloomProgress != bloomProgress ||
        oldDelegate.plantKind != plantKind ||
        oldDelegate.bouquet != bouquet ||
        oldDelegate.leaves != leaves;
  }
}

class _BloomPlant {
  const _BloomPlant({
    required this.kind,
    required this.dx,
    required this.scale,
    required this.stem,
    required this.swayMul,
    required this.lean,
  });

  final AppFabPlantKind kind;
  final double dx;
  final double scale;
  final double stem;
  final double swayMul;
  final double lean;
}

List<AppFabLeafSpec> generateAppFabLeaves(math.Random rng) {
  return _generateLeaves(
    rng,
    count: 5 + rng.nextInt(3),
    distanceMin: 36,
    distanceSpan: 28,
    sizeMin: 5.5,
    sizeSpan: 3.5,
  );
}

/// Smaller leaf burst for the expense-form category chip settle animation.
List<AppFabLeafSpec> generateCategoryChipLeaves(math.Random rng) {
  return _generateLeaves(
    rng,
    count: 4 + rng.nextInt(3),
    distanceMin: 18,
    distanceSpan: 14,
    sizeMin: 3.5,
    sizeSpan: 2.5,
  );
}

List<AppFabLeafSpec> _generateLeaves(
  math.Random rng, {
  required int count,
  required double distanceMin,
  required double distanceSpan,
  required double sizeMin,
  required double sizeSpan,
}) {
  const greens = <Color>[
    Color(0xFF66BB6A),
    Color(0xFF43A047),
    Color(0xFF81C784),
    Color(0xFF2E7D32),
    Color(0xFFA5D6A7),
  ];
  return List<AppFabLeafSpec>.generate(count, (i) {
    final spread = (i / count) * math.pi * 2 + rng.nextDouble() * 0.4;
    return AppFabLeafSpec(
      angle: spread - math.pi / 2 + (rng.nextDouble() - 0.5) * 0.8,
      distance: distanceMin + rng.nextDouble() * distanceSpan,
      spin: (rng.nextDouble() - 0.5) * 3.2,
      delay: rng.nextDouble() * 0.18,
      color: greens[rng.nextInt(greens.length)],
      size: sizeMin + rng.nextDouble() * sizeSpan,
    );
  });
}
