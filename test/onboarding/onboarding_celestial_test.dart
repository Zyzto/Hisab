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

  test('contentStartY sits just below the disc for a phone viewport', () {
    const screen = Size(390, 844);
    final start = OnboardingCelestial.contentStartY(screen);
    // Disc radius = min*0.075 = 29.25; center at max(0.15*H, halo*0.9).
    expect(start, greaterThan(screen.height * 0.15));
    expect(start, lessThan(screen.height * 0.28));
    expect(OnboardingCelestial.contentStartY(Size.zero), 0);
  });
}
