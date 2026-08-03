import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/navigation/invite_auth_helpers.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';
import 'package:hisab/features/settings/settings_definitions.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SettingsProviders> settingsOf(WidgetTester tester) async {
    final settings = await tester.runAsync(() async {
      return initializeSettings(
        registry: createHisabSettingsRegistry(),
        storage: MemoryStorage(),
      );
    });
    expect(settings, isNotNull);
    return settings!;
  }

  /// Pump a [Consumer] so we can obtain a [WidgetRef], then run [body]
  /// after build (helpers must not write providers during build).
  Future<void> runWithRef(
    WidgetTester tester,
    SettingsProviders settings,
    Future<void> Function(WidgetRef ref) body,
  ) async {
    final completer = <WidgetRef?>[null];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hisabSettingsProvidersProvider.overrideWithValue(settings),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            completer[0] = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    final ref = completer[0];
    expect(ref, isNotNull);
    await body(ref!);
    await tester.pump();
    // Flush logging aggregation timer started by invite helpers.
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('prepareInviteJoinPending sets token + auto-join', (
    tester,
  ) async {
    final settings = await settingsOf(tester);
    await settings.controller.set(localOnlySettingDef, true);

    await runWithRef(tester, settings, (ref) async {
      prepareInviteJoinPending(ref, 'tok-abc');
    });

    expect(settings.controller.get(pendingInviteTokenSettingDef), 'tok-abc');
    expect(settings.controller.get(pendingInviteAutoJoinSettingDef), isTrue);
  });

  testWidgets('persistPendingInviteToken does not force auto-join', (
    tester,
  ) async {
    final settings = await settingsOf(tester);
    await settings.controller.set(pendingInviteAutoJoinSettingDef, false);

    await runWithRef(tester, settings, (ref) async {
      persistPendingInviteToken(ref, 'tok-view');
    });

    expect(settings.controller.get(pendingInviteTokenSettingDef), 'tok-view');
    expect(settings.controller.get(pendingInviteAutoJoinSettingDef), isFalse);
  });

  testWidgets('markInviteOnboardingDone is idempotent', (tester) async {
    final settings = await settingsOf(tester);
    await settings.controller.set(onboardingCompletedSettingDef, false);

    await runWithRef(tester, settings, (ref) async {
      markInviteOnboardingDone(ref);
      markInviteOnboardingDone(ref);
    });

    expect(settings.controller.get(onboardingCompletedSettingDef), isTrue);
  });

  testWidgets(
    'clearInviteFlowState clears token, auto-join, and invite last-route',
    (tester) async {
      final settings = await settingsOf(tester);
      await settings.controller.set(pendingInviteTokenSettingDef, 'tok');
      await settings.controller.set(pendingInviteAutoJoinSettingDef, true);
      await settings.controller.set(
        lastRoutePathSettingDef,
        '/invite/tok/preview',
      );

      await runWithRef(tester, settings, (ref) async {
        clearInviteFlowState(ref);
      });

      expect(settings.controller.get(pendingInviteTokenSettingDef), isEmpty);
      expect(settings.controller.get(pendingInviteAutoJoinSettingDef), isFalse);
      expect(settings.controller.get(lastRoutePathSettingDef), isEmpty);
    },
  );

  testWidgets('clearInviteFlowState leaves non-invite last-route alone', (
    tester,
  ) async {
    final settings = await settingsOf(tester);
    await settings.controller.set(pendingInviteTokenSettingDef, 'tok');
    await settings.controller.set(lastRoutePathSettingDef, '/groups/g1');

    await runWithRef(tester, settings, (ref) async {
      clearInviteFlowState(ref);
    });

    expect(settings.controller.get(pendingInviteTokenSettingDef), isEmpty);
    expect(settings.controller.get(lastRoutePathSettingDef), '/groups/g1');
  });
}
