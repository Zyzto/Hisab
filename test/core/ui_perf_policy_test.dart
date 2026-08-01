import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/platform/ui_perf_logic.dart';

void main() {
  group('UiPerfPolicy', () {
    test('iOS web gets aggressive cheap paths', () {
      const p = UiPerfPolicy(
        isWebIos: true,
        isWebAndroid: false,
        isWebMobile: true,
        isNativeIos: false,
        isNativeAndroid: false,
      );
      expect(p.preferCheapShadows, isTrue);
      expect(p.preferInstantShellTabs, isTrue);
      expect(p.preferCheapCharts, isTrue);
      expect(p.preferFadeOnlyPageTransitions, isTrue);
      expect(p.preferReducedChromeMotion, isTrue);
      expect(p.preferCheapListDrag, isTrue);
    });

    test('Android web keeps polish but cheap charts on mobile', () {
      const p = UiPerfPolicy(
        isWebIos: false,
        isWebAndroid: true,
        isWebMobile: true,
        isNativeIos: false,
        isNativeAndroid: false,
      );
      expect(p.preferCheapShadows, isFalse);
      expect(p.preferInstantShellTabs, isFalse);
      expect(p.preferCheapCharts, isTrue);
      expect(p.preferFadeOnlyPageTransitions, isFalse);
      expect(p.preferReducedChromeMotion, isFalse);
      expect(p.preferCheapListDrag, isFalse);
    });

    test('desktop web keeps full polish', () {
      const p = UiPerfPolicy(
        isWebIos: false,
        isWebAndroid: false,
        isWebMobile: false,
        isNativeIos: false,
        isNativeAndroid: false,
      );
      expect(p.preferCheapShadows, isFalse);
      expect(p.preferInstantShellTabs, isFalse);
      expect(p.preferCheapCharts, isFalse);
      expect(p.preferFadeOnlyPageTransitions, isFalse);
      expect(p.preferReducedChromeMotion, isFalse);
      expect(p.preferCheapListDrag, isFalse);
    });

    test('native iOS/Android keep full polish', () {
      const ios = UiPerfPolicy(
        isWebIos: false,
        isWebAndroid: false,
        isWebMobile: false,
        isNativeIos: true,
        isNativeAndroid: false,
      );
      const android = UiPerfPolicy(
        isWebIos: false,
        isWebAndroid: false,
        isWebMobile: false,
        isNativeIos: false,
        isNativeAndroid: true,
      );
      for (final p in [ios, android]) {
        expect(p.preferCheapShadows, isFalse);
        expect(p.preferInstantShellTabs, isFalse);
        expect(p.preferCheapCharts, isFalse);
        expect(p.preferFadeOnlyPageTransitions, isFalse);
        expect(p.preferReducedChromeMotion, isFalse);
        expect(p.preferCheapListDrag, isFalse);
      }
    });
  });
}
