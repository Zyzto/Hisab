import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../celebration_fx.dart';
import '../celebration_game.dart';

/// Full-screen quiet dusk sky + moon (personal list).
class DuskScene extends PositionComponent
    with HasGameReference<CelebrationGame> {
  DuskScene({math.Random? rng}) : _rng = rng ?? math.Random();

  final math.Random _rng;
  List<_Star> _stars = const [];
  double _intro = 0;
  bool _built = false;

  double get alpha => game.sceneAlpha;
  double get intro => Curves.easeOut.transform(_intro);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.topLeft;
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
    if (_built || size.x <= 0) return;
    _built = true;
    _stars = List.generate(celebrationBudget(28), (i) {
      return _Star(
        offset: Vector2(
          _rng.nextDouble() * size.x,
          _rng.nextDouble() * size.y * 0.7,
        ),
        phase: i * 0.9,
        size: 1.4 + _rng.nextDouble() * 2.2,
      );
    });
    add(
      _Moon()
        ..position = Vector2(size.x * 0.72, size.y * 0.22)
        ..anchor = Anchor.center,
    );
    add(
      mistOrbs(rng: _rng, tint: const Color(0xFF9FA8DA), area: size, count: 12),
    );
    add(
      burstCircles(
        rng: _rng,
        count: 12,
        origin: Vector2(size.x * 0.5, size.y * 0.35),
        colors: const [Color(0xFFE8EAF6), Color(0xFFFFF8E1)],
        radius: 2.5,
        acceleration: Vector2(0, 20),
        spread: 280,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_intro < 1) _intro = (_intro + dt / 0.5).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    final a = alpha;
    if (a <= 0) return;

    final rect = Offset.zero & Size(size.x, size.y);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A237E).withValues(alpha: 0.35 * a * intro),
            const Color(0xFF5C6BC0).withValues(alpha: 0.22 * a * intro),
            const Color(0xFFFFCC80).withValues(alpha: 0.12 * a * intro),
          ],
        ).createShader(rect),
    );

    for (final s in _stars) {
      final tw = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(game.elapsed * 5 + s.phase));
      canvas.drawCircle(
        Offset(s.offset.x, s.offset.y),
        s.size * intro,
        Paint()
          ..color = const Color(0xFFE8EAF6).withValues(alpha: 0.65 * a * tw),
      );
    }

    // Horizon glow
    canvas.drawRect(
      Rect.fromLTWH(0, size.y * 0.72, size.x, size.y * 0.28),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFAB40).withValues(alpha: 0.0),
            const Color(0xFFFF8A65).withValues(alpha: 0.18 * a * intro),
          ],
        ).createShader(Rect.fromLTWH(0, size.y * 0.72, size.x, size.y * 0.28)),
    );

    // Slow cloud
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.18 * a)
      ..style = PaintingStyle.fill;
    final drift = game.progress * size.x * 0.12;
    canvas.save();
    canvas.translate(size.x * 0.2 + drift, size.y * 0.35);
    canvas.scale(1.6 * intro);
    canvas.drawCircle(const Offset(-20, 0), 24, p);
    canvas.drawCircle(const Offset(8, -10), 28, p);
    canvas.drawCircle(const Offset(32, 2), 20, p);
    canvas.restore();
  }
}

class _Moon extends PositionComponent with HasGameReference<CelebrationGame> {
  double _growT = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    scale = Vector2.all(0.2);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_growT < 1) {
      _growT = (_growT + dt / 0.6).clamp(0.0, 1.0);
      final eased = Curves.easeOutBack.transform(_growT);
      final unit = game.size.y / 500;
      scale = Vector2.all((0.2 + 0.8 * eased).clamp(0.2, 1.3) * unit);
    }
    // Rise slightly
    if (isMounted && game.hasLayout) {
      position.y = game.size.y * (0.28 - 0.08 * game.progress);
    }
  }

  @override
  void render(Canvas canvas) {
    final a = game.sceneAlpha;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF8E1).withValues(alpha: 0.4 * a),
          const Color(0xFFFFF8E1).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 90));
    canvas.drawCircle(Offset.zero, 90, glow);
    canvas.drawCircle(
      Offset.zero,
      36,
      Paint()..color = const Color(0xFFFFFDE7).withValues(alpha: 0.88 * a),
    );
    canvas.drawCircle(
      const Offset(-10, 6),
      8,
      Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.28 * a),
    );
    canvas.drawCircle(
      const Offset(12, -8),
      5,
      Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.2 * a),
    );
  }
}

class _Star {
  _Star({required this.offset, required this.phase, required this.size});
  final Vector2 offset;
  final double phase;
  final double size;
}
