import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/onboarding/widgets/onboarding_theme_ripple.dart';

void main() {
  test('themeRippleMaxRadius reaches the farthest corner', () {
    const size = Size(100, 200);
    expect(
      themeRippleMaxRadius(size, Offset.zero),
      moreOrLessEquals(223.6, epsilon: 0.1),
    );
    expect(
      themeRippleMaxRadius(size, const Offset(100, 200)),
      moreOrLessEquals(223.6, epsilon: 0.1),
    );
    expect(
      themeRippleMaxRadius(size, const Offset(50, 100)),
      moreOrLessEquals(111.8, epsilon: 0.1),
    );
  });

  test('themeRippleFillForMode matches the onboarding chip', () {
    expect(
      themeRippleFillForMode('light', platformBrightness: Brightness.dark),
      kOnboardingThemeLightFill,
    );
    expect(
      themeRippleFillForMode('dark', platformBrightness: Brightness.light),
      kOnboardingThemeDarkFill,
    );
    expect(
      themeRippleFillForMode('amoled', platformBrightness: Brightness.light),
      kOnboardingThemeAmoledFill,
    );
    expect(
      themeRippleFillForMode('system', platformBrightness: Brightness.light),
      kOnboardingThemeLightFill,
    );
    expect(
      themeRippleFillForMode('system', platformBrightness: Brightness.dark),
      kOnboardingThemeDarkFill,
    );
  });

  test('themeRippleRingForMode contrasts the fill', () {
    expect(
      themeRippleRingForMode('light', platformBrightness: Brightness.dark),
      kOnboardingThemeLightIcon,
    );
    expect(
      themeRippleRingForMode('dark', platformBrightness: Brightness.light),
      kOnboardingThemeDarkIcon,
    );
    expect(
      themeRippleRingForMode('system', platformBrightness: Brightness.dark),
      kOnboardingThemeDarkIcon,
    );
  });

  test('themeRippleOriginForButton falls back when boxes are missing', () {
    expect(themeRippleOriginForButton(button: null, host: null), Offset.zero);
  });

  test('reveal clipper punches a hole from the origin', () {
    const size = Size(100, 100);
    const origin = Offset(50, 50);
    expect(
      ThemeRippleRevealClipper(
        origin: origin,
        progress: 0,
      ).getClip(size).contains(origin),
      isTrue,
    );
    expect(
      ThemeRippleRevealClipper(
        origin: origin,
        progress: 1,
      ).getClip(size).contains(origin),
      isFalse,
    );
  });

  testWidgets('OnboardingThemeRipple paints from a driving animation', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: kOnboardingThemeRippleDuration,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingThemeRipple(
          animation: controller,
          origin: const Offset(40, 40),
        ),
      ),
    );
    controller.value = 0.4;
    await tester.pump();
    expect(find.byType(OnboardingThemeRipple), findsOneWidget);
  });
}
