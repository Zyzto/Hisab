import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/onboarding/widgets/onboarding_celestial.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void drive(OnboardingCelestial body, Vector2 viewport) {
    body.onGameResize(viewport);
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    // Long enough for motes to run past their lifespan and be recycled.
    for (var i = 0; i < 600; i++) {
      body.update(1 / 60);
      body.render(canvas);
    }
    recorder.endRecording().dispose();
  }

  test('renders across day, night and viewport shapes', () {
    for (final night in [false, true]) {
      for (final viewport in [
        Vector2(390, 844),
        Vector2(1440, 900),
        Vector2(800, 360),
      ]) {
        expect(
          () => drive(OnboardingCelestial(night: night), viewport),
          returnsNormally,
        );
      }
    }
  });

  test('ignores a degenerate viewport instead of drawing', () {
    final body = OnboardingCelestial(night: false)
      ..onGameResize(Vector2.zero());
    final recorder = PictureRecorder();
    body.render(Canvas(recorder));
    recorder.endRecording().dispose();
  });
}
