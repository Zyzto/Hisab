import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/auth/auth_pending_finalize.dart';
import 'package:hisab/core/settings/settings_definitions.dart';

void main() {
  Future<SettingsController> buildController({
    bool onboardingPending = false,
    bool settingsPending = false,
    bool localOnly = true,
    bool onboardingCompleted = false,
  }) async {
    final controller = SettingsController(
      registry: createHisabSettingsRegistry(),
      storage: MemoryStorage(),
    );
    await controller.init();
    await controller.set(onboardingOnlinePendingSettingDef, onboardingPending);
    await controller.set(settingsOnlinePendingSettingDef, settingsPending);
    await controller.set(localOnlySettingDef, localOnly);
    await controller.set(onboardingCompletedSettingDef, onboardingCompleted);
    return controller;
  }

  test(
    'session + onboarding pending completes onboarding and online',
    () async {
      final c = await buildController(onboardingPending: true);
      finalizePendingOnlineAuth(controller: c, hasSession: true);
      expect(c.get(onboardingOnlinePendingSettingDef), isFalse);
      expect(c.get(localOnlySettingDef), isFalse);
      expect(c.get(onboardingCompletedSettingDef), isTrue);
    },
  );

  test('session + settings pending clears flag and sets online', () async {
    final c = await buildController(settingsPending: true);
    finalizePendingOnlineAuth(controller: c, hasSession: true);
    expect(c.get(settingsOnlinePendingSettingDef), isFalse);
    expect(c.get(localOnlySettingDef), isFalse);
  });

  test('no session does not clear pending unless clearWhenNoSession', () async {
    final c = await buildController(
      onboardingPending: true,
      settingsPending: true,
    );
    finalizePendingOnlineAuth(controller: c, hasSession: false);
    expect(c.get(onboardingOnlinePendingSettingDef), isTrue);
    expect(c.get(settingsOnlinePendingSettingDef), isTrue);

    finalizePendingOnlineAuth(
      controller: c,
      hasSession: false,
      clearWhenNoSession: true,
    );
    expect(c.get(onboardingOnlinePendingSettingDef), isFalse);
    expect(c.get(settingsOnlinePendingSettingDef), isFalse);
  });

  test(
    'warm resume (clearWhenNoSession=false) keeps flags until session',
    () async {
      final c = await buildController(
        onboardingPending: true,
        settingsPending: true,
      );
      // Native magic-link: app resumes before deep-link session arrives.
      finalizePendingOnlineAuth(
        controller: c,
        hasSession: false,
        clearWhenNoSession: false,
      );
      expect(c.get(onboardingOnlinePendingSettingDef), isTrue);
      expect(c.get(settingsOnlinePendingSettingDef), isTrue);

      finalizePendingOnlineAuth(controller: c, hasSession: true);
      expect(c.get(onboardingOnlinePendingSettingDef), isFalse);
      expect(c.get(settingsOnlinePendingSettingDef), isFalse);
      expect(c.get(localOnlySettingDef), isFalse);
      expect(c.get(onboardingCompletedSettingDef), isTrue);
    },
  );

  test('idempotent when flags already clear', () async {
    final c = await buildController(
      onboardingCompleted: true,
      localOnly: false,
    );
    finalizePendingOnlineAuth(controller: c, hasSession: true);
    expect(c.get(onboardingOnlinePendingSettingDef), isFalse);
    expect(c.get(settingsOnlinePendingSettingDef), isFalse);
    expect(c.get(onboardingCompletedSettingDef), isTrue);
    expect(c.get(localOnlySettingDef), isFalse);
  });

  test('both pending flags finalize together when session exists', () async {
    final c = await buildController(
      onboardingPending: true,
      settingsPending: true,
      localOnly: true,
    );
    finalizePendingOnlineAuth(controller: c, hasSession: true);
    expect(c.get(onboardingOnlinePendingSettingDef), isFalse);
    expect(c.get(settingsOnlinePendingSettingDef), isFalse);
    expect(c.get(localOnlySettingDef), isFalse);
    expect(c.get(onboardingCompletedSettingDef), isTrue);
  });

  test('session without pending flags does not flip local_only', () async {
    final c = await buildController(localOnly: true);
    finalizePendingOnlineAuth(controller: c, hasSession: true);
    expect(c.get(localOnlySettingDef), isTrue);
    expect(c.get(onboardingCompletedSettingDef), isFalse);
  });

  test(
    'auth-callback session completes onboarding even without pending flag',
    () async {
      final c = await buildController(localOnly: true);
      finalizePendingOnlineAuth(
        controller: c,
        hasSession: true,
        fromAuthCallback: true,
      );
      expect(c.get(onboardingCompletedSettingDef), isTrue);
      expect(c.get(localOnlySettingDef), isFalse);
      expect(c.get(onboardingOnlinePendingSettingDef), isFalse);
    },
  );

  test(
    'auth-callback session with onboarding already done still goes online',
    () async {
      final c = await buildController(
        onboardingCompleted: true,
        localOnly: true,
      );
      finalizePendingOnlineAuth(
        controller: c,
        hasSession: true,
        fromAuthCallback: true,
      );
      expect(c.get(onboardingCompletedSettingDef), isTrue);
      expect(c.get(localOnlySettingDef), isFalse);
    },
  );

  test('auth-callback without session does not complete onboarding', () async {
    final c = await buildController(onboardingPending: true);
    finalizePendingOnlineAuth(
      controller: c,
      hasSession: false,
      fromAuthCallback: true,
      clearWhenNoSession: true,
    );
    expect(c.get(onboardingCompletedSettingDef), isFalse);
    expect(c.get(onboardingOnlinePendingSettingDef), isFalse);
  });
}
