import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/pwa/pwa_capabilities.dart';

void main() {
  group('stub defaults', () {
    test('are safe for non-web', () {
      expect(isPwaStandalone, isTrue);
      expect(isPwaMobile, isFalse);
      expect(isPwaIos, isFalse);
      expect(isPwaAndroid, isFalse);
      expect(canPromptPwaInstall, isFalse);
      // Non-web: treat as already installed so install UI stays hidden.
      expect(pwaInstallMode, PwaInstallMode.alreadyInstalled);
      expect(pwaNotificationSupport, PwaNotificationSupport.supported);
    });

    test('promptPwaInstall is a no-op outside web', () async {
      expect(await promptPwaInstall(), isFalse);
    });

    test('listeners are accepted outside web', () {
      var called = false;
      void listener() => called = true;
      addPwaCapabilityListener(listener);
      removePwaCapabilityListener(listener);
      expect(called, isFalse);
    });
  });

  group('resolvePwaInstallMode', () {
    test('already installed wins', () {
      expect(
        resolvePwaInstallMode(
          isStandalone: true,
          isMobile: true,
          canPromptInstall: true,
          isIos: true,
          isAndroid: false,
        ),
        PwaInstallMode.alreadyInstalled,
      );
    });

    test('desktop is unsupported', () {
      expect(
        resolvePwaInstallMode(
          isStandalone: false,
          isMobile: false,
          canPromptInstall: true,
          isIos: false,
          isAndroid: false,
        ),
        PwaInstallMode.unsupported,
      );
    });

    test('native prompt preferred on Android when available', () {
      expect(
        resolvePwaInstallMode(
          isStandalone: false,
          isMobile: true,
          canPromptInstall: true,
          isIos: false,
          isAndroid: true,
        ),
        PwaInstallMode.nativePrompt,
      );
    });

    test('iOS without prompt uses manual iOS steps', () {
      expect(
        resolvePwaInstallMode(
          isStandalone: false,
          isMobile: true,
          canPromptInstall: false,
          isIos: true,
          isAndroid: false,
        ),
        PwaInstallMode.manualIos,
      );
    });

    test('Android without prompt uses manual Android steps', () {
      expect(
        resolvePwaInstallMode(
          isStandalone: false,
          isMobile: true,
          canPromptInstall: false,
          isIos: false,
          isAndroid: true,
        ),
        PwaInstallMode.manualAndroid,
      );
    });
  });

  group('resolvePwaNotificationSupport', () {
    test('unsupported when Notification API missing', () {
      expect(
        resolvePwaNotificationSupport(
          notificationApiAvailable: false,
          isIos: false,
          isStandalone: false,
        ),
        PwaNotificationSupport.unsupported,
      );
    });

    test('iOS browser tab needs install', () {
      expect(
        resolvePwaNotificationSupport(
          notificationApiAvailable: true,
          isIos: true,
          isStandalone: false,
        ),
        PwaNotificationSupport.needsInstall,
      );
    });

    test('iOS Home Screen PWA is supported', () {
      expect(
        resolvePwaNotificationSupport(
          notificationApiAvailable: true,
          isIos: true,
          isStandalone: true,
        ),
        PwaNotificationSupport.supported,
      );
    });

    test('Android browser tab is supported', () {
      expect(
        resolvePwaNotificationSupport(
          notificationApiAvailable: true,
          isIos: false,
          isStandalone: false,
        ),
        PwaNotificationSupport.supported,
      );
    });
  });

  group('useIosInstallGuide', () {
    test('true for manual iOS mode', () {
      expect(
        useIosInstallGuide(mode: PwaInstallMode.manualIos, isIos: false),
        isTrue,
      );
    });

    test('true when device is iOS even if mode is native/manual Android', () {
      expect(
        useIosInstallGuide(mode: PwaInstallMode.manualAndroid, isIos: true),
        isTrue,
      );
    });

    test('false for Android manual path', () {
      expect(
        useIosInstallGuide(mode: PwaInstallMode.manualAndroid, isIos: false),
        isFalse,
      );
    });
  });
}
