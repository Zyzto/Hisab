import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../celebration_fx.dart';
import 'biome_scene_base.dart';

/// Full-screen climbing vines from the edges (new expense).
class PlantsScene extends BiomeSceneBase {
  @override
  void spawnAmbient() {
    add(
      shapedBurst(
        rng: rng,
        count: 20,
        origin: Vector2(area.x * 0.5, area.y * 0.65),
        colors: const [
          Color(0xFF7CB342),
          Color(0xFF9CCC65),
          Color(0xFF558B2F),
          Color(0xFFAED581),
        ],
        draw: drawLeaf,
        spread: 380,
        minSize: 10,
        maxSize: 20,
      ),
    );
    add(
      screenRain(
        rng: rng,
        area: area,
        count: 16,
        colors: const [Color(0xFFDCEDC8), Color(0xFFC5E1A5), Color(0xFFAED581)],
        draw: drawLeaf,
        fallDown: false,
      ),
    );
    add(
      burstCircles(
        rng: rng,
        count: 14,
        origin: Vector2(area.x * 0.5, area.y * 0.7),
        colors: const [Color(0xFFF0F4C3), Color(0xFFDCEDC8)],
        radius: 3.5,
        acceleration: Vector2(0, -30),
        spread: 260,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final a = alpha;
    if (a <= 0) return;
    paintWash(canvas, const Color(0xFF33691E), strength: 0.16);

    final w = size.x;
    final h = size.y;
    final grow = intro;

    // Side vines climbing full height
    _drawVineColumn(canvas, w * 0.12, grow, a, left: true);
    _drawVineColumn(canvas, w * 0.88, grow, a, left: false);

    // Ground foliage band
    final bush = Paint()
      ..color = const Color(0xFF558B2F).withValues(alpha: 0.4 * a * grow);
    for (var i = 0; i < 8; i++) {
      final x = w * (i + 0.5) / 8;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, h * 0.92),
          width: w * 0.22,
          height: h * 0.12,
        ),
        bush,
      );
    }
  }

  void _drawVineColumn(
    Canvas canvas,
    double x,
    double grow,
    double a, {
    required bool left,
  }) {
    final h = size.y;
    final sway = math.sin(game.elapsed * 2.5 + x) * 18;
    final tipY = h * (1 - 0.85 * grow);

    final vine = Paint()
      ..color = const Color(0xFF558B2F).withValues(alpha: 0.9 * a)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(x, h);
    path.cubicTo(
      x + (left ? -30 : 30),
      h * 0.7,
      x + sway,
      h * 0.4,
      x + sway * 0.6,
      tipY,
    );
    canvas.drawPath(path, vine);

    final leaf = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 8; i++) {
      final tt = (i + 1) / 9;
      if (tt > grow) continue;
      final y = h - tt * (h - tipY);
      final lx = x + math.sin(tt * math.pi * 3 + game.elapsed) * 22 + sway * tt;
      canvas.save();
      canvas.translate(lx, y);
      canvas.rotate(
        (left ? -0.8 : 0.8) + math.sin(game.elapsed * 3 + i) * 0.15,
      );
      leaf.color =
          (i.isEven ? const Color(0xFF7CB342) : const Color(0xFF9CCC65))
              .withValues(alpha: 0.88 * a);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 28, height: 14),
        leaf,
      );
      canvas.restore();
    }
  }
}
