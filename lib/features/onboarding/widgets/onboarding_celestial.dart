import 'dart:math' as math;

import 'package:flame/camera.dart' as flame_camera;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../core/platform/ui_perf.dart';

/// Procedural sun (day) / moon (night) drawn over the parallax sky.
///
/// The sky textures ship without a celestial body so this one can move: the
/// halo breathes, the disc drifts on a slow bob, and motes rise around it.
/// Everything is vector so it stays crisp at any viewport size.
///
/// The disc itself is always a clean circle. Only the sun's glow layers
/// undulate; the moon keeps a plain, still halo.
class OnboardingCelestial extends PositionComponent {
  OnboardingCelestial({
    required bool night,
    math.Random? rng,
    super.priority,
  })  : _night = night,
        _rng = rng ?? math.Random(7);

  final bool _night;
  final math.Random _rng;
  final List<_Mote> _motes = [];

  double _elapsed = 0;
  Offset _center = Offset.zero;
  double _radius = 0;
  double _haloRadius = 0;
  double _coronaRadius = 0;
  Paint? _halo;
  Paint? _corona;
  Paint? _disc;
  late final Paint _mote = Paint()
    ..color = _night ? const Color(0xFFDCE9FF) : const Color(0xFFFFF0B0);

  bool get _cheap => UiPerf.preferCheapCharts;

  int get _moteCount => _cheap ? 8 : 18;

  /// Only the sun gets the rippling glow; the moon reads better plain.
  bool get _rippling => !_night;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final parentSize = parent is flame_camera.Viewport
        ? (parent! as flame_camera.Viewport).virtualSize
        : size;
    this.size.setFrom(parentSize);
    position.setValues(0, 0);
    _layout();
  }

  void _layout() {
    if (size.x <= 0 || size.y <= 0) return;
    _radius = (math.min(size.x, size.y) * 0.075).clamp(22.0, 56.0);
    _haloRadius = _radius * (_rippling ? 3.2 : 3.0);
    _coronaRadius = _radius * 1.8;
    // Keep the body inside the right edge with room for the full halo, and
    // clear of the top so it reads as a risen sun rather than a clipped one.
    final x = math.min(size.x * 0.80, size.x - _haloRadius);
    final y = math.max(size.y * 0.15, _haloRadius * 0.9);
    _center = Offset(x, y);
    _buildPaints();
    _seedMotes();
  }

  void _buildPaints() {
    final haloTint =
        _night ? const Color(0xFFDCE9FF) : const Color(0xFFFFE066);
    const coronaTint = Color(0xFFFFF8DC);
    final peak = _night ? 0.46 : 0.78;
    _halo = Paint()
      ..shader = RadialGradient(
        // Extra stops keep the falloff from ending on a visible circular edge
        // against the flat sky.
        colors: [
          haloTint.withValues(alpha: peak),
          haloTint.withValues(alpha: peak * 0.62),
          haloTint.withValues(alpha: peak * 0.24),
          haloTint.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.30, 0.58, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset.zero, radius: _haloRadius),
      );
    // Tight bloom hugging the disc so the sun reads as the light source
    // rather than a soft blob floating in haze.
    _corona = _rippling
        ? (Paint()
          ..shader = RadialGradient(
            colors: [
              coronaTint.withValues(alpha: 0.72),
              coronaTint.withValues(alpha: 0.40),
              coronaTint.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.62, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: _coronaRadius),
          ))
        : null;
    _disc = Paint()
      ..shader = RadialGradient(
        // The sun is a hot near-white core that only warms up toward the rim,
        // like a real one blown out against the sky.
        colors: _night
            ? const [Color(0xFFFFFDF0), Color(0xFFE8E2C8)]
            : const [
                Color(0xFFFFFFFF),
                Color(0xFFFFFAE8),
                Color(0xFFFFEDB4),
              ],
        stops: _night ? const [0.0, 1.0] : const [0.0, 0.52, 1.0],
        center: const Alignment(-0.2, -0.3),
      ).createShader(
        Rect.fromCircle(center: Offset.zero, radius: _radius),
      );
  }

  void _seedMotes() {
    _motes.clear();
    for (var i = 0; i < _moteCount; i++) {
      _motes.add(_spawnMote(life: i / _moteCount));
    }
  }

  /// Golden-angle steps keep successive motes spread around the disc; pure
  /// random angles clump into visible gaps at these small counts.
  static const double _goldenAngle = math.pi * (3 - 2.23606797749979);

  int _spawned = 0;

  _Mote _spawnMote({double life = 0}) {
    final angle = _spawned++ * _goldenAngle + (_rng.nextDouble() - 0.5) * 0.35;
    return _Mote(
      angle: angle,
      drift: (_rng.nextDouble() - 0.5) * 1.2,
      speed: 0.10 + _rng.nextDouble() * 0.14,
      radius: 1.4 + _rng.nextDouble() * 2.6,
      twinklePhase: _rng.nextDouble() * math.pi * 2,
      life: life,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    for (var i = 0; i < _motes.length; i++) {
      final mote = _motes[i];
      mote.life += dt * mote.speed;
      if (mote.life >= 1) {
        _motes[i] = _spawnMote();
      }
    }
  }

  /// Closed blob whose radius is modulated by two harmonics, so the outline
  /// undulates like hand-painted light instead of sitting as a hard circle.
  ///
  /// Both harmonics use whole lobe counts, which keeps the wave periodic over
  /// a full turn and the path seamless where it closes.
  Path _glowBlob({
    required double radius,
    required double amplitude,
    required double phase,
    required int lobes,
  }) {
    final segments = _cheap ? 28 : 44;
    final points = List<Offset>.generate(segments, (i) {
      final theta = i / segments * math.pi * 2;
      final wave = 0.66 * math.sin(lobes * theta + phase) +
          0.34 * math.sin((lobes + 3) * theta - phase * 0.7);
      // The gradient fades to zero alpha exactly at [radius], so the outline
      // is biased fully outside it — a wave that dips back inside clips the
      // fill while it still has alpha, leaving a faint visible rim.
      final r = radius * (1 + amplitude * (wave + 1));
      return Offset(math.cos(theta) * r, math.sin(theta) * r);
    });

    // Quadratics through edge midpoints: the sampled points become control
    // handles, so the outline stays round instead of reading as a polygon.
    Offset midpoint(Offset a, Offset b) =>
        Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

    final start = midpoint(points.last, points.first);
    final path = Path()..moveTo(start.dx, start.dy);
    for (var i = 0; i < segments; i++) {
      final current = points[i];
      final next = points[(i + 1) % segments];
      final mid = midpoint(current, next);
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    return path..close();
  }

  @override
  void render(Canvas canvas) {
    final halo = _halo;
    final corona = _corona;
    final disc = _disc;
    if (halo == null || disc == null || _radius <= 0) return;

    final bob = math.sin(_elapsed * 0.45) * _radius * 0.10;
    final pulse = 1.0 + math.sin(_elapsed * 0.8) * 0.07;

    canvas.save();
    canvas.translate(_center.dx, _center.dy + bob);

    canvas.save();
    canvas.scale(pulse);
    if (_rippling) {
      canvas.drawPath(
        _glowBlob(
          radius: _haloRadius,
          amplitude: 0.10,
          phase: _elapsed * -0.42,
          lobes: 3,
        ),
        halo,
      );
      if (corona != null) {
        canvas.drawPath(
          _glowBlob(
            radius: _coronaRadius,
            amplitude: 0.085,
            phase: _elapsed * 0.6,
            lobes: 3,
          ),
          corona,
        );
      }
    } else {
      canvas.drawCircle(Offset.zero, _haloRadius, halo);
    }
    canvas.restore();

    _renderMotes(canvas);
    canvas.drawCircle(Offset.zero, _radius, disc);
    canvas.restore();
  }

  void _renderMotes(Canvas canvas) {
    final base = _mote.color;
    for (final mote in _motes) {
      // Fade in from the rim, fade out at the end of the drift.
      final fade = math.sin(mote.life * math.pi);
      if (fade <= 0.01) continue;
      final twinkle =
          0.6 + 0.4 * math.sin(_elapsed * 3 + mote.twinklePhase);
      final distance = _radius * (1.2 + 2.0 * mote.life);
      final angle = mote.angle + mote.drift * mote.life;
      final offset = Offset(
        math.cos(angle) * distance,
        math.sin(angle) * distance - _radius * 0.7 * mote.life,
      );
      _mote.color = base.withValues(alpha: fade * twinkle * 0.75);
      canvas.drawCircle(offset, mote.radius, _mote);
    }
    _mote.color = base;
  }
}

class _Mote {
  _Mote({
    required this.angle,
    required this.drift,
    required this.speed,
    required this.radius,
    required this.twinklePhase,
    required this.life,
  });

  final double angle;
  final double drift;
  final double speed;
  final double radius;
  final double twinklePhase;
  double life;
}
