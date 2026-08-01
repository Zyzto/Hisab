import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'celebration_fx.dart';
import 'celebration_kind.dart';
import 'scenes/celebration_scenes.dart';

/// Short-lived Flame overlay for one [CelebrationKind] biome.
class CelebrationGame extends FlameGame {
  CelebrationGame({
    required this.kind,
    required this.onComplete,
  });

  final CelebrationKind kind;
  final VoidCallback onComplete;

  double durationSec = 2.5;
  double elapsed = 0;
  bool _completed = false;

  /// 0–1 timeline progress.
  double get progress => (elapsed / durationSec).clamp(0.0, 1.0);

  /// Combined fade-in / fade-out alpha for scene paints.
  double get sceneAlpha => celebrationSceneAlpha(progress);

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    durationSec = celebrationDurationSeconds(kind);
    // Viewport (not world): Flame's default camera is centered on (0,0), so a
    // top-left full-screen component in the world only paints the bottom-right
    // screen quadrant. Viewport children use screen coordinates.
    camera.viewport.add(buildCelebrationScene(kind));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_completed) return;
    elapsed += dt;
    if (elapsed >= durationSec) {
      _completed = true;
      onComplete();
    }
  }

  /// Advance the timeline without a widget tree (unit tests).
  @visibleForTesting
  void debugAdvance(double seconds) {
    const step = 1 / 60;
    var left = seconds;
    while (left > 0 && !_completed) {
      final dt = left > step ? step : left;
      update(dt);
      left -= dt;
    }
  }
}
