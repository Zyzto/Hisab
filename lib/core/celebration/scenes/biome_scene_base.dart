import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../celebration_game.dart';

/// Full-screen biome scene: fills the viewport, no tiny centered vignette.
abstract class BiomeSceneBase extends PositionComponent
    with HasGameReference<CelebrationGame> {
  BiomeSceneBase({math.Random? rng}) : rng = rng ?? math.Random();

  final math.Random rng;
  double _intro = 0;
  bool _ambientSpawned = false;

  double get alpha => game.sceneAlpha;

  /// 0→1 intro grow for hero elements (does not shrink the whole scene).
  double get intro => Curves.easeOutCubic.transform(_intro);

  Vector2 get area => size;

  Offset get screenCenter => Offset(size.x / 2, size.y / 2);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.topLeft;
    position = Vector2.zero();
    _fit();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _fit();
  }

  void _fit() {
    if (!game.hasLayout) return;
    size.setFrom(game.size);
    position = Vector2.zero();
    if (!_ambientSpawned && size.x > 0 && size.y > 0) {
      _ambientSpawned = true;
      spawnAmbient();
    }
  }

  /// Optional particles / ambient children (use screen coordinates).
  void spawnAmbient() {}

  /// Soft full-screen color wash so the biome reads as a screen event.
  void paintWash(Canvas canvas, Color tint, {double strength = 0.22}) {
    final a = alpha * strength;
    if (a <= 0) return;
    final rect = Offset.zero & Size(size.x, size.y);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint.withValues(alpha: a * 0.55),
            tint.withValues(alpha: a),
            tint.withValues(alpha: a * 0.7),
          ],
        ).createShader(rect),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_intro < 1) {
      _intro = (_intro + dt / 0.55).clamp(0.0, 1.0);
    }
  }
}
