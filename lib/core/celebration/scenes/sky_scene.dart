import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../celebration_fx.dart';
import '../celebration_game.dart';

/// Full-screen sky farewell — clouds + birds across the viewport (person left).
class SkyScene extends PositionComponent
    with HasGameReference<CelebrationGame> {
  SkyScene({math.Random? rng}) : _rng = rng ?? math.Random();

  final math.Random _rng;
  List<_Cloud> _clouds = const [];
  List<_Bird> _birds = const [];
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
    _clouds = List.generate(celebrationBudget(6), (i) {
      return _Cloud(
        offset: Vector2(
          _rng.nextDouble() * size.x * 0.7,
          size.y * (0.08 + 0.35 * (i / 6)),
        ),
        scale: 0.9 + _rng.nextDouble() * 0.8,
        speed: 40 + i * 18.0 + _rng.nextDouble() * 20,
      );
    });
    _birds = List.generate(celebrationBudget(10), (i) {
      return _Bird(
        offset: Vector2(
          size.x * (0.05 + 0.08 * i),
          size.y * (0.2 + 0.05 * (i % 4)),
        ),
        speed: 90 + i * 16.0,
        flapPhase: i * 0.7,
      );
    });
    add(
      mistOrbs(rng: _rng, tint: const Color(0xFFBBDEFB), area: size, count: 12),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_intro < 1) _intro = (_intro + dt / 0.45).clamp(0.0, 1.0);
    for (final c in _clouds) {
      c.offset.x += c.speed * dt;
      if (c.offset.x > size.x + 80) c.offset.x = -120;
    }
    for (final b in _birds) {
      b.offset.x += b.speed * dt;
      b.offset.y += math.sin(game.elapsed * 4 + b.flapPhase) * 18 * dt;
    }
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
            const Color(0xFF90CAF9).withValues(alpha: 0.28 * a * intro),
            const Color(0xFFE3F2FD).withValues(alpha: 0.18 * a * intro),
            const Color(0xFFFFFFFF).withValues(alpha: 0.05 * a),
          ],
        ).createShader(rect),
    );

    for (final c in _clouds) {
      _drawCloud(
        canvas,
        Offset(c.offset.x, c.offset.y),
        c.scale * intro,
        a * 0.85,
      );
    }

    final bird = Paint()
      ..color = const Color(0xFF455A64).withValues(alpha: 0.75 * a)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final b in _birds) {
      final flap = math.sin(game.elapsed * 11 + b.flapPhase) * 6;
      final o = Offset(b.offset.x, b.offset.y);
      final path = Path()
        ..moveTo(o.dx - 14, o.dy)
        ..quadraticBezierTo(o.dx, o.dy - 10 - flap, o.dx + 6, o.dy)
        ..quadraticBezierTo(o.dx + 16, o.dy - 10 + flap, o.dx + 26, o.dy + 2);
      canvas.drawPath(path, bird);
    }
  }

  void _drawCloud(Canvas canvas, Offset c, double scale, double a) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 * a)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);
    canvas.drawCircle(const Offset(-28, 0), 30, p);
    canvas.drawCircle(const Offset(8, -14), 36, p);
    canvas.drawCircle(const Offset(40, 4), 26, p);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(4, 14), width: 110, height: 40),
      p,
    );
    canvas.restore();
  }
}

class _Cloud {
  _Cloud({required this.offset, required this.scale, required this.speed});
  Vector2 offset;
  final double scale;
  final double speed;
}

class _Bird {
  _Bird({required this.offset, required this.speed, required this.flapPhase});
  Vector2 offset;
  final double speed;
  final double flapPhase;
}
