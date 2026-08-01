import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../celebration_fx.dart';
import 'biome_scene_base.dart';

/// Full-screen sea wash + ripples (settlement).
class SeaScene extends BiomeSceneBase {
  @override
  void spawnAmbient() {
    add(
      shapedBurst(
        rng: rng,
        count: 20,
        origin: Vector2(area.x * 0.5, area.y * 0.55),
        colors: const [
          Color(0xFF4FC3F7),
          Color(0xFF29B6F6),
          Color(0xFF81D4FA),
          Color(0xFFE1F5FE),
        ],
        draw: drawDroplet,
        spread: 400,
        minSize: 8,
        maxSize: 18,
      ),
    );
    add(
      burstCircles(
        rng: rng,
        count: 18,
        origin: Vector2(area.x * 0.5, area.y * 0.6),
        colors: const [Color(0xFFFFFFFF), Color(0xFFB3E5FC)],
        radius: 3.5,
        acceleration: Vector2(0, 60),
        spread: 360,
      ),
    );
    add(
      screenRain(
        rng: rng,
        area: area,
        count: 14,
        colors: const [Color(0xFF81D4FA), Color(0xFFE1F5FE)],
        draw: drawDroplet,
        fallDown: true,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final a = alpha;
    if (a <= 0) return;
    paintWash(canvas, const Color(0xFF01579B), strength: 0.22);

    final w = size.x;
    final h = size.y;
    final t = game.elapsed;
    final grow = intro;

    // Deep water band across lower half
    final water = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0288D1).withValues(alpha: 0.15 * a * grow),
          const Color(0xFF01579B).withValues(alpha: 0.45 * a * grow),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.4, w, h * 0.6));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.4, w, h * 0.6), water);

    // Expanding ripples from center
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final cx = w * 0.5;
    final cy = h * 0.55;
    for (var i = 0; i < 7; i++) {
      final phase = (t * 1.1 + i * 0.14) % 1.0;
      final r = (40 + phase * math.min(w, h) * 0.55) * grow;
      ripple.color =
          const Color(0xFF4FC3F7).withValues(alpha: (1 - phase) * 0.45 * a);
      canvas.drawCircle(Offset(cx, cy), r, ripple);
    }

    // Rolling wave crests across width
    final foam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = Colors.white.withValues(alpha: 0.4 * a);
    for (var band = 0; band < 4; band++) {
      final yBase = h * (0.5 + band * 0.1);
      final path = Path();
      for (var i = 0; i <= 24; i++) {
        final x = w * i / 24;
        final y = yBase +
            math.sin(i * 0.7 + t * 3 + band) * 14 * grow +
            math.sin(i * 0.3 + t) * 6;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, foam);
    }

    // Horizon shimmer
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.38, w, 3),
      Paint()..color = Colors.white.withValues(alpha: 0.2 * a * grow),
    );
  }
}
