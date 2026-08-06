import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../celebration_fx.dart';
import 'biome_scene_base.dart';

/// Full-screen forest canopy rising (first expense).
class ForestScene extends BiomeSceneBase {
  @override
  void spawnAmbient() {
    add(
      mistOrbs(rng: rng, tint: const Color(0xFFA5D6A7), area: area, count: 16),
    );
    add(
      shapedBurst(
        rng: rng,
        count: 22,
        origin: Vector2(area.x * 0.5, area.y * 0.55),
        colors: const [
          Color(0xFF2E7D32),
          Color(0xFF558B2F),
          Color(0xFF8D6E63),
          Color(0xFFA5D6A7),
        ],
        draw: drawNeedle,
        spread: 420,
        minSize: 10,
        maxSize: 22,
      ),
    );
    add(
      screenRain(
        rng: rng,
        area: area,
        count: 18,
        colors: const [Color(0xFF66BB6A), Color(0xFF81C784), Color(0xFFA5D6A7)],
        draw: drawNeedle,
        fallDown: true,
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

    // Ground band
    final ground = Paint()
      ..color = const Color(0xFF33691E).withValues(alpha: 0.35 * a);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.72, w, h * 0.28), ground);

    // Row of pines across the bottom half
    final trees = celebrationBudget(7);
    for (var i = 0; i < trees; i++) {
      final t = (i + 0.5) / trees;
      final x = w * t;
      final baseY = h * (0.78 + 0.04 * math.sin(i * 1.7));
      final scale = (0.55 + 0.45 * ((i % 3) / 2)) * grow;
      final sway = math.sin(game.elapsed * 2.2 + i) * 0.04;
      _drawPine(canvas, Offset(x, baseY), scale, sway, a);
    }

    // Distant canopy silhouette along the top
    final canopy = Paint()
      ..color = const Color(0xFF0D3B14).withValues(alpha: 0.28 * a * grow);
    final path = Path()..moveTo(0, h * 0.18);
    for (var i = 0; i <= 10; i++) {
      final x = w * i / 10;
      final y = h * (0.08 + 0.06 * math.sin(i * 1.1 + game.elapsed));
      path.lineTo(x, y);
    }
    path
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, canopy);
  }

  void _drawPine(Canvas canvas, Offset base, double s, double sway, double a) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(sway);
    canvas.scale(s);

    final trunk = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: 0.9 * a)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 0), const Offset(0, -90), trunk);

    final pine = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 4; i++) {
      final y = -40.0 - i * 38.0;
      final ww = 70.0 - i * 12.0;
      pine.color = Color.lerp(
        const Color(0xFF1B5E20),
        const Color(0xFF66BB6A),
        i / 3,
      )!.withValues(alpha: 0.92 * a);
      canvas.drawPath(
        Path()
          ..moveTo(0, y - 50)
          ..lineTo(ww, y + 18)
          ..lineTo(-ww, y + 18)
          ..close(),
        pine,
      );
    }
    canvas.restore();
  }
}
