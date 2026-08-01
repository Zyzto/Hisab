import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart';

import '../platform/ui_perf.dart';
import 'celebration_kind.dart';

/// Like [ParticleSystemComponent], but clears the particle instead of calling
/// [removeFromParent] during [update] (avoids concurrent modification while the
/// parent iterates children).
class CelebrationParticles extends ParticleSystemComponent {
  CelebrationParticles({required super.particle, super.position});

  @override
  void update(double dt) {
    particle?.update(dt);
    if (particle?.shouldRemove ?? false) {
      particle = null;
    }
  }
}

/// Duration for each biome celebration (seconds).
double celebrationDurationSeconds(CelebrationKind kind) {
  return celebrationDuration(kind).inMilliseconds / 1000.0;
}

Duration celebrationDuration(CelebrationKind kind) {
  return switch (kind) {
    CelebrationKind.firstExpense => const Duration(milliseconds: 3200),
    CelebrationKind.newGroup => const Duration(milliseconds: 3000),
    CelebrationKind.newPersonalList => const Duration(milliseconds: 2800),
    CelebrationKind.personJoined => const Duration(milliseconds: 2800),
    CelebrationKind.settlement => const Duration(milliseconds: 2600),
    CelebrationKind.personLeft => const Duration(milliseconds: 2400),
    CelebrationKind.newExpense => const Duration(milliseconds: 2200),
  };
}

/// Scene opacity: quick fade-in, hold, then fade-out.
double celebrationSceneAlpha(double t) {
  final clamped = t.clamp(0.0, 1.0);
  final fadeIn = Curves.easeOut.transform((clamped / 0.12).clamp(0.0, 1.0));
  final fadeOut = clamped < 0.72
      ? 1.0
      : (1.0 - Curves.easeIn.transform((clamped - 0.72) / 0.28)).clamp(
          0.0,
          1.0,
        );
  return fadeIn * fadeOut;
}

/// Particle / entity budget for mobile web vs full desktop/native.
int celebrationBudget(int full) {
  if (UiPerf.preferReducedChromeMotion) {
    return math.max(4, (full * 0.4).round());
  }
  if (UiPerf.preferCheapCharts) {
    return math.max(6, (full * 0.6).round());
  }
  return full;
}

Vector2 randomBurstSpeed(
  math.Random rng, {
  double spread = 280,
  double upwardBias = 80,
}) {
  final angle = rng.nextDouble() * math.pi * 2;
  final mag = 60 + rng.nextDouble() * spread;
  return Vector2(
    math.cos(angle) * mag,
    math.sin(angle) * mag - upwardBias,
  );
}

/// Screen-wide radial burst of circles from [origin].
CelebrationParticles burstCircles({
  required math.Random rng,
  required int count,
  required List<Color> colors,
  Vector2? origin,
  double lifespan = 1.4,
  double radius = 4,
  Vector2? acceleration,
  double spread = 320,
}) {
  final n = celebrationBudget(count);
  final base = origin ?? Vector2.zero();
  return CelebrationParticles(
    position: base,
    particle: Particle.generate(
      count: n,
      lifespan: lifespan,
      generator: (i) {
        final color = colors[i % colors.length];
        return AcceleratedParticle(
          acceleration: acceleration ?? Vector2(0, 140),
          speed: randomBurstSpeed(rng, spread: spread),
          child: CircleParticle(
            radius: radius * (0.7 + rng.nextDouble() * 0.8),
            paint: Paint()..color = color.withValues(alpha: 0.8),
          ),
        );
      },
    ),
  );
}

/// Soft mist orbs drifting across a [area] (screen region).
CelebrationParticles mistOrbs({
  required math.Random rng,
  required Color tint,
  required Vector2 area,
  int count = 14,
  double lifespan = 2.6,
}) {
  final n = celebrationBudget(count);
  return CelebrationParticles(
    particle: Particle.generate(
      count: n,
      lifespan: lifespan,
      generator: (i) {
        final from = Vector2(
          rng.nextDouble() * area.x,
          rng.nextDouble() * area.y,
        );
        final to = from +
            Vector2(
              (rng.nextDouble() - 0.5) * area.x * 0.35,
              -40 - rng.nextDouble() * area.y * 0.2,
            );
        return MovingParticle(
          from: from,
          to: to,
          child: CircleParticle(
            radius: 28 + rng.nextDouble() * 48,
            paint: Paint()..color = tint.withValues(alpha: 0.12),
          ),
        );
      },
    ),
  );
}

/// Custom-shaped burst across the screen from [origin].
CelebrationParticles shapedBurst({
  required math.Random rng,
  required int count,
  required List<Color> colors,
  required void Function(Canvas canvas, Paint paint, double size) draw,
  Vector2? origin,
  double lifespan = 1.4,
  double spread = 300,
  double minSize = 8,
  double maxSize = 18,
}) {
  final n = celebrationBudget(count);
  final base = origin ?? Vector2.zero();
  return CelebrationParticles(
    position: base,
    particle: Particle.generate(
      count: n,
      lifespan: lifespan,
      generator: (i) {
        final color = colors[i % colors.length];
        final size = minSize + rng.nextDouble() * (maxSize - minSize);
        final spin = (rng.nextDouble() - 0.5) * 6;
        return AcceleratedParticle(
          acceleration: Vector2(0, 110),
          speed: randomBurstSpeed(rng, spread: spread),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final a = (1.0 - particle.progress) * 0.9;
              canvas.save();
              canvas.rotate(spin * particle.progress);
              draw(
                canvas,
                Paint()..color = color.withValues(alpha: a),
                size,
              );
              canvas.restore();
            },
          ),
        );
      },
    ),
  );
}

/// Falling / rising shapes raining across the full width.
CelebrationParticles screenRain({
  required math.Random rng,
  required Vector2 area,
  required int count,
  required List<Color> colors,
  required void Function(Canvas canvas, Paint paint, double size) draw,
  double lifespan = 2.2,
  bool fallDown = true,
}) {
  final n = celebrationBudget(count);
  return CelebrationParticles(
    particle: Particle.generate(
      count: n,
      lifespan: lifespan,
      generator: (i) {
        final color = colors[i % colors.length];
        final size = 7 + rng.nextDouble() * 12;
        final x = rng.nextDouble() * area.x;
        final fromY = fallDown ? -20.0 - rng.nextDouble() * 40 : area.y + 20;
        final toY = fallDown ? area.y + 40 : -40.0;
        final spin = (rng.nextDouble() - 0.5) * 4;
        return MovingParticle(
          from: Vector2(x, fromY),
          to: Vector2(x + (rng.nextDouble() - 0.5) * 80, toY),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final a = (1.0 - (particle.progress - 0.5).abs() * 1.6)
                  .clamp(0.0, 0.85);
              canvas.save();
              canvas.rotate(spin * particle.progress);
              draw(
                canvas,
                Paint()..color = color.withValues(alpha: a),
                size,
              );
              canvas.restore();
            },
          ),
        );
      },
    ),
  );
}

void drawNeedle(Canvas canvas, Paint paint, double size) {
  canvas.drawPath(
    Path()
      ..moveTo(0, -size)
      ..lineTo(size * 0.35, size * 0.6)
      ..lineTo(-size * 0.35, size * 0.6)
      ..close(),
    paint,
  );
}

void drawLeaf(Canvas canvas, Paint paint, double size) {
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: size * 1.8, height: size),
    paint,
  );
}

void drawDroplet(Canvas canvas, Paint paint, double size) {
  canvas.drawPath(
    Path()
      ..moveTo(0, -size)
      ..quadraticBezierTo(size * 0.7, 0, 0, size)
      ..quadraticBezierTo(-size * 0.7, 0, 0, -size)
      ..close(),
    paint,
  );
}

void drawTropicalLeaf(Canvas canvas, Paint paint, double size) {
  canvas.drawPath(
    Path()
      ..moveTo(0, size * 0.8)
      ..cubicTo(size * 0.5, size * 0.2, size, -size * 0.2, size * 0.9, -size)
      ..cubicTo(size * 0.3, -size * 0.6, -size * 0.2, -size * 0.4, 0, size * 0.8)
      ..close(),
    paint,
  );
}
