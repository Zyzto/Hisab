import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../celebration_fx.dart';
import '../celebration_game.dart';
import 'biome_scene_base.dart';

/// Full-screen grove of trees rising (new group).
class GroveScene extends BiomeSceneBase {
  @override
  void spawnAmbient() {
    add(
      mistOrbs(
        rng: rng,
        tint: const Color(0xFFC8E6C9),
        area: area,
        count: 14,
      ),
    );
    add(
      shapedBurst(
        rng: rng,
        count: 20,
        origin: Vector2(area.x * 0.5, area.y * 0.6),
        colors: const [
          Color(0xFF2E7D32),
          Color(0xFF388E3C),
          Color(0xFF6D4C41),
          Color(0xFF81C784),
        ],
        draw: drawNeedle,
        spread: 400,
        minSize: 10,
        maxSize: 20,
      ),
    );
    add(
      screenRain(
        rng: rng,
        area: area,
        count: 14,
        colors: const [Color(0xFF81C784), Color(0xFFA5D6A7)],
        draw: drawLeaf,
      ),
    );

    final count = celebrationBudget(8);
    for (var i = 0; i < count; i++) {
      final t = (i + 0.5) / count;
      add(
        _GroveTree(
          color: Color.lerp(
            const Color(0xFF2E7D32),
            const Color(0xFF66BB6A),
            i / count,
          )!,
          treeScale: 0.7 + (i % 3) * 0.15,
          startDelay: 0.06 * i,
        )..position = Vector2(area.x * t, area.y * (0.82 + 0.03 * math.sin(i))),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final a = alpha;
    if (a <= 0) return;
    paintWash(canvas, const Color(0xFF1B5E20), strength: 0.18);

    final w = size.x;
    final h = size.y;
    // Meadow band
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.7, w, h * 0.3),
      Paint()..color = const Color(0xFF558B2F).withValues(alpha: 0.3 * a * intro),
    );
  }
}

class _GroveTree extends PositionComponent
    with HasGameReference<CelebrationGame> {
  _GroveTree({
    required this.color,
    required this.treeScale,
    required this.startDelay,
  });

  final Color color;
  final double treeScale;
  final double startDelay;
  double _growT = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.bottomCenter;
    scale = Vector2.all(0.05);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.elapsed < startDelay) return;
    if (_growT < 1) {
      _growT = (_growT + dt / 0.5).clamp(0.0, 1.0);
      final eased = Curves.easeOutBack.transform(_growT);
      final s = (0.05 + 0.95 * eased).clamp(0.05, 1.25) * treeScale;
      // Scale relative to screen height so trees feel large.
      final unit = game.size.y / 420;
      scale = Vector2.all(s * unit);
    }
    angle = math.sin(game.elapsed * 2.2 + position.x) * 0.04;
  }

  @override
  void render(Canvas canvas) {
    final a = game.sceneAlpha;
    final trunk = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: 0.9 * a)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 0), const Offset(0, -120), trunk);

    final canopy = Paint()
      ..color = color.withValues(alpha: 0.9 * a)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(0, -150), 55, canopy);
    canvas.drawCircle(const Offset(-40, -120), 40, canopy);
    canvas.drawCircle(const Offset(40, -120), 40, canopy);
    canvas.drawCircle(const Offset(0, -100), 36, canopy);

    final speck = Paint()
      ..color = const Color(0xFFC8E6C9).withValues(alpha: 0.35 * a);
    for (var i = 0; i < 5; i++) {
      final ang = i * math.pi / 2.5;
      canvas.drawCircle(
        Offset(math.cos(ang) * 28, -140 + math.sin(ang) * 22),
        4,
        speck,
      );
    }
  }
}
