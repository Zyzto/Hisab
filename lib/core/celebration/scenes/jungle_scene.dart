import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import '../celebration_fx.dart';
import 'biome_scene_base.dart';

/// Full-screen jungle fronds + fireflies (person joined).
class JungleScene extends BiomeSceneBase {
  @override
  void spawnAmbient() {
    add(
      shapedBurst(
        rng: rng,
        count: 18,
        origin: Vector2(area.x * 0.5, area.y * 0.6),
        colors: const [
          Color(0xFF43A047),
          Color(0xFF66BB6A),
          Color(0xFF33691E),
          Color(0xFFFFF59D),
        ],
        draw: drawTropicalLeaf,
        spread: 400,
        minSize: 12,
        maxSize: 24,
      ),
    );
    final flies = celebrationBudget(22);
    add(
      CelebrationParticles(
        particle: Particle.generate(
          count: flies,
          lifespan: 2.5,
          generator: (i) {
            final ox = rng.nextDouble() * area.x;
            final oy = rng.nextDouble() * area.y * 0.75;
            final orbit = 20.0 + (i % 5) * 14;
            final phase = i * 0.55;
            return ComputedParticle(
              renderer: (canvas, particle) {
                final tt = particle.progress * math.pi * 2 + phase + game.elapsed;
                final x = ox + math.cos(tt * 1.2) * orbit;
                final y = oy + math.sin(tt * 1.6) * orbit * 0.5;
                final tw = 0.3 +
                    0.7 * (0.5 + 0.5 * math.sin(game.elapsed * 11 + i));
                canvas.drawCircle(
                  Offset(x, y),
                  2.4 + (i.isEven ? 1.2 : 0),
                  Paint()
                    ..color = const Color(0xFFFFF59D)
                        .withValues(alpha: 0.7 * alpha * tw),
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final a = alpha;
    if (a <= 0) return;
    paintWash(canvas, const Color(0xFF1B5E20), strength: 0.2);

    final w = size.x;
    final h = size.y;
    final grow = intro;

    // Large fronds from left and right edges
    final frondCount = celebrationBudget(5);
    for (var i = 0; i < frondCount; i++) {
      final y = h * (0.15 + 0.7 * i / frondCount);
      _drawFrond(
        canvas,
        Offset(0, y),
        grow,
        a,
        flip: false,
        sway: math.sin(game.elapsed * 2 + i) * 0.12,
      );
      _drawFrond(
        canvas,
        Offset(w, y + h * 0.05),
        grow * 0.95,
        a,
        flip: true,
        sway: math.sin(game.elapsed * 2.3 + i) * 0.12,
      );
    }

    // Center spears rising
    for (final fx in [0.35, 0.5, 0.65]) {
      final x = w * fx;
      final sway = math.sin(game.elapsed * 2.8 + fx * 10) * 0.06;
      canvas.save();
      canvas.translate(x, h);
      canvas.rotate(sway);
      canvas.scale(grow);
      final spear = Paint()
        ..color = const Color(0xFF33691E).withValues(alpha: 0.88 * a)
        ..style = PaintingStyle.fill;
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(14, -h * 0.35)
          ..lineTo(0, -h * 0.72)
          ..lineTo(-14, -h * 0.35)
          ..close(),
        spear,
      );
      canvas.restore();
    }
  }

  void _drawFrond(
    Canvas canvas,
    Offset origin,
    double grow,
    double a, {
    required bool flip,
    required double sway,
  }) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(flip ? -1.0 : 1.0, 1.0);
    canvas.rotate(-0.35 + sway);
    canvas.scale(grow);

    final leaf = Paint()
      ..color = const Color(0xFF43A047).withValues(alpha: 0.85 * a)
      ..style = PaintingStyle.fill;
    final reach = size.x * 0.55;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..cubicTo(reach * 0.25, -40, reach * 0.7, -30, reach, -80)
        ..cubicTo(reach * 0.55, 10, reach * 0.2, 50, 0, 0)
        ..close(),
      leaf,
    );
    final slit = Paint()
      ..color = const Color(0xFF1B5E20).withValues(alpha: 0.35 * a)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(reach * 0.25, -10), Offset(reach * 0.45, -40), slit);
    canvas.drawLine(Offset(reach * 0.4, 5), Offset(reach * 0.65, -25), slit);
    canvas.restore();
  }
}
