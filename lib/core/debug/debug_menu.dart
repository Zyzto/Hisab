import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';

import '../../features/expenses/camera/receipt_camera_debug.dart';
import '../../features/settings/feedback_handler.dart';
import '../../features/settings/providers/settings_framework_providers.dart';
import '../../features/settings/settings_definitions.dart';
import '../celebration/celebration_controller.dart';
import '../celebration/celebration_dedupe.dart';
import '../celebration/celebration_kind.dart';
import '../database/database_providers.dart';
import '../layout/responsive_sheet.dart';
import '../navigation/route_paths.dart';
import '../platform/screenshot_report_support.dart';
import '../platform/ui_perf.dart';
import '../services/connectivity_service.dart';
import '../widgets/app_fab.dart';
import '../widgets/error_content.dart';
import '../widgets/sheet_helpers.dart';
import '../widgets/toast.dart';
import 'integration_test_mode.dart';

/// Async package-name check (Android `.debug` suffix) for non-`kDebugMode` builds.
final packageIsDebugBuildProvider = FutureProvider<bool>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.packageName.contains('.debug');
  } catch (_) {
    return false;
  }
});

/// Whether the debug menu FAB should be shown.
///
/// Synchronous for `kDebugMode` so the first frame is not blank while a
/// [FutureProvider] loads (important on web-server).
final showDebugMenuProvider = Provider<bool>((ref) {
  if (isIntegrationTestMode) return false;
  if (kDebugMode) return true;
  return ref.watch(packageIsDebugBuildProvider).asData?.value ?? false;
});

/// Small floating bug-icon button shown only on debug builds.
///
/// [navigatorKey] is resolved on press so a null [BuildContext] on the first
/// frames (before the navigator mounts) does not permanently disable the menu.
///
/// [localeContext] must have [EasyLocalization] (e.g. MaterialApp builder).
class DebugMenuFab extends ConsumerWidget {
  const DebugMenuFab({
    super.key,
    required this.upgrader,
    required this.navigatorKey,
    required this.localeContext,
    this.onBeforeOpen,
    this.whenSheetClosed,
  });

  final Upgrader upgrader;
  final GlobalKey<NavigatorState> navigatorKey;
  final BuildContext? localeContext;
  final VoidCallback? onBeforeOpen;
  final VoidCallback? whenSheetClosed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.small(
      heroTag: 'debugMenuFab',
      tooltip: 'debug_menu_title'.tr(),
      backgroundColor: Theme.of(
        context,
      ).colorScheme.errorContainer.withValues(alpha: 0.9),
      foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
      onPressed: () {
        final navContext = navigatorKey.currentContext;
        final locContext = localeContext;
        if (navContext == null ||
            !navContext.mounted ||
            locContext == null ||
            !locContext.mounted) {
          return;
        }
        onBeforeOpen?.call();
        showResponsiveSheet<void>(
          context: navContext,
          title: 'debug_menu_title'.tr(),
          isScrollControlled: true,
          centerInFullViewport: false,
          child: EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('ar')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            startLocale: locContext.locale,
            child: _DebugMenuSheet(upgrader: upgrader, hostContext: navContext),
          ),
        ).whenComplete(() => whenSheetClosed?.call());
      },
      child: const Icon(Icons.bug_report_outlined, size: 20),
    );
  }
}

class _DebugMenuSheet extends ConsumerStatefulWidget {
  const _DebugMenuSheet({required this.upgrader, required this.hostContext});

  final Upgrader upgrader;

  /// Navigator context outside this sheet — used after the sheet closes so
  /// celebrations / toasts still have a mounted Overlay.
  final BuildContext hostContext;

  @override
  ConsumerState<_DebugMenuSheet> createState() => _DebugMenuSheetState();
}

class _DebugMenuSheetState extends ConsumerState<_DebugMenuSheet> {
  String? _statusMessage;
  Future<PackageInfo>? _packageInfoFuture;

  static const _celebrationLabels = <CelebrationKind, String>{
    CelebrationKind.firstExpense: 'Forest — first expense',
    CelebrationKind.newExpense: 'Plants — new expense',
    CelebrationKind.settlement: 'Sea — settlement',
    CelebrationKind.personJoined: 'Jungle — person joined',
    CelebrationKind.personLeft: 'Sky — person left',
    CelebrationKind.newGroup: 'Grove — new group',
    CelebrationKind.newPersonalList: 'Dusk — personal list',
  };

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  /// Pop the sheet, then run [action] with objects captured *before* dispose.
  Future<void> _closeThen(void Function(BuildContext host) action) async {
    final host = widget.hostContext;
    Navigator.of(context, rootNavigator: true).pop();
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!host.mounted) return;
    action(host);
  }

  Future<void> _forceUpgradeDialog() async {
    await Upgrader.clearSavedSettings();
    widget.upgrader.updateState(
      widget.upgrader.state.copyWith(debugDisplayAlways: true),
    );
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _triggerSync() async {
    _setStatus('Syncing…');
    try {
      await ref.read(dataSyncServiceProvider.notifier).syncNow();
      _setStatus('Sync complete');
    } catch (e) {
      _setStatus('Sync failed: $e');
    }
  }

  void _resetOnboarding() {
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings == null) {
      _setStatus('Settings not available');
      return;
    }
    unawaited(
      ref
          .read(settings.provider(onboardingCompletedSettingDef).notifier)
          .set(false),
    );
    _setStatus('Onboarding reset — restart the app');
  }

  Future<void> _openInviteByToken() async {
    final token = await showTextInputSheet(
      context,
      title: 'Open invite by token',
      hint: 'Paste invite token',
    );
    if (token != null && token.isNotEmpty && mounted) {
      final host = widget.hostContext;
      Navigator.of(context, rootNavigator: true).pop();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (host.mounted) {
        GoRouter.of(host).go(RoutePaths.inviteAccept(token));
      }
    }
  }

  void _showErrorUI() {
    showResponsiveSheet<void>(
      context: context,
      title: 'Error (debug)',
      isScrollControlled: true,
      centerInFullViewport: false,
      child: Builder(
        builder: (sheetContext) => SingleChildScrollView(
          child: ErrorContentWidget(
            message:
                'Sample error for testing the error UI. Use Share/Report to verify actions.',
            onRetry: () => Navigator.of(sheetContext).pop(),
            details: 'Debug-triggered sample error.\nStack trace omitted.',
          ),
        ),
      ),
    );
  }

  Future<void> _waitForCelebrationIdle(CelebrationController bus) async {
    if (bus.active == null) return;
    final completer = Completer<void>();
    void listener() {
      if (bus.active == null && !completer.isCompleted) {
        bus.removeListener(listener);
        completer.complete();
      }
    }

    bus.addListener(listener);
    try {
      await completer.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      bus.removeListener(listener);
    }
  }

  Future<void> _playCelebration(CelebrationKind kind) async {
    // Capture before pop — sheet State (and [ref]) is disposed after close.
    final bus = ref.read(celebrationControllerProvider);
    await _closeThen((_) => bus.request(kind));
  }

  Future<void> _playAllCelebrations() async {
    final bus = ref.read(celebrationControllerProvider);
    final host = widget.hostContext;
    Navigator.of(context, rootNavigator: true).pop();
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!host.mounted) return;

    // Play one-by-one: production queue only keeps ~2 pending items.
    for (final kind in CelebrationKind.values) {
      if (!host.mounted) return;
      bus.request(kind);
      await _waitForCelebrationIdle(bus);
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  Future<void> _clearCelebrationDedupe() async {
    await CelebrationDedupe.instance.debugClearAll();
    _setStatus('Celebration dedupe cleared');
  }

  Future<void> _setExtraAnimations(bool enabled) async {
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings == null) {
      _setStatus('Settings not available');
      return;
    }
    await ref
        .read(settings.provider(extraAnimationsEnabledSettingDef).notifier)
        .set(enabled);
    _setStatus(enabled ? 'Extra animations ON' : 'Extra animations OFF');
  }

  Future<void> _setScreenshotPrompt(bool enabled) async {
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings == null) {
      _setStatus('Settings not available');
      return;
    }
    await ref
        .read(
          settings.provider(screenshotReportPromptEnabledSettingDef).notifier,
        )
        .set(enabled);
    _setStatus(
      enabled ? 'Screenshot report prompt ON' : 'Screenshot report prompt OFF',
    );
  }

  Future<void> _simulateScreenshotPrompt() async {
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (supportsScreenshotReportPrompt &&
        settings != null &&
        !ref.read(screenshotReportPromptEnabledProvider)) {
      await ref
          .read(
            settings.provider(screenshotReportPromptEnabledSettingDef).notifier,
          )
          .set(true);
    }
    final message = 'screenshot_report_prompt_message'.tr();
    final actionLabel = 'report_issue'.tr();
    await _closeThen((host) {
      host.showPromptWithAction(
        message,
        actionLabel: actionLabel,
        onAction: () {
          if (!host.mounted) return;
          try {
            BetterFeedback.of(host).hide();
            BetterFeedback.of(
              host,
            ).show((feedback) => handleFeedback(host, feedback: feedback));
          } catch (_) {}
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extrasOn = ref.watch(extraAnimationsEnabledProvider);
    final screenshotOn = ref.watch(screenshotReportPromptEnabledProvider);
    final reduced = UiPerf.preferReducedChromeMotion;
    final syncOverride = ref.watch(debugSyncStatusOverrideProvider);
    final receiptCameraMock = ref.watch(debugReceiptCameraMockProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<PackageInfo>(
              future: _packageInfoFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      kDebugMode ? 'debug' : 'profile/release',
                      style: textTheme.bodySmall,
                    ),
                  );
                }
                final info = snap.data!;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Package', value: info.packageName),
                      _InfoRow(
                        label: 'Version',
                        value: '${info.version} (${info.buildNumber})',
                      ),
                      const _InfoRow(
                        label: 'Mode',
                        value: kDebugMode ? 'debug' : 'profile/release',
                      ),
                      _InfoRow(
                        label: 'Reduced motion',
                        value: reduced ? 'yes (UiPerf)' : 'no',
                      ),
                    ],
                  ),
                );
              },
            ),

            const _SectionHeader('Celebrations'),
            Text(
              'Closes the menu, then plays the biome overlay. Bypasses the Extra animations setting.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in CelebrationKind.values)
                  ActionChip(
                    avatar: Icon(_iconForCelebration(kind), size: 16),
                    label: Text(_celebrationLabels[kind] ?? kind.name),
                    onPressed: () => unawaited(_playCelebration(kind)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => unawaited(_playAllCelebrations()),
                  icon: const Icon(Icons.playlist_play, size: 18),
                  label: const Text('Play all'),
                ),
                TextButton.icon(
                  onPressed: () => unawaited(_clearCelebrationDedupe()),
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: const Text('Clear join/leave dedupe'),
                ),
              ],
            ),

            const _SectionHeader('Animations'),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.animation, size: 22),
              title: const Text('Extra animations'),
              subtitle: Text(
                extrasOn
                    ? 'ON — FAB nature + event celebrations'
                    : 'OFF — press scale only',
              ),
              value: extrasOn,
              onChanged: (v) => unawaited(_setExtraAnimations(v)),
            ),
            if (reduced)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'UiPerf reduced motion is on (e.g. iOS Safari) — FAB extras stay muted in-app; celebration chips still preview.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.tertiary,
                  ),
                ),
              ),
            Text(
              extrasOn
                  ? 'FAB playground — each tap cycles the next flower (all kinds, then bouquets).'
                  : 'Turn on Extra animations above to preview FAB nature effects.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: AppFab(
                icon: Icons.add,
                tooltip: 'Debug FAB',
                heroTag: 'debugMenuAppFabPreview',
                previewAmbientBloom: true,
                onPressed: () => _setStatus('FAB pressed (leaf burst)'),
              ),
            ),

            const _SectionHeader('Screenshot report'),
            if (!supportsScreenshotReportPrompt)
              Text(
                'OS screenshot detection is iOS/Android only. You can still simulate the prompt toast below.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (supportsScreenshotReportPrompt)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.screenshot_monitor, size: 22),
                title: const Text('Screenshot → report prompt'),
                value: screenshotOn,
                onChanged: (v) => unawaited(_setScreenshotPrompt(v)),
              ),
            _DebugAction(
              icon: Icons.notification_important_outlined,
              label: 'Simulate screenshot prompt',
              subtitle: supportsScreenshotReportPrompt
                  ? 'Shows the toast + Report action (enables setting)'
                  : 'Shows the toast UI (OS capture N/A on this platform)',
              onTap: () => unawaited(_simulateScreenshotPrompt()),
            ),

            const _SectionHeader('Receipt camera'),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.receipt_long_outlined, size: 22),
              title: const Text('Mock camera preview'),
              subtitle: Text(
                receiptCameraMock
                    ? 'ON — animated fake receipt (desktop + mobile)'
                    : 'OFF — real camera on phone; file picker on desktop',
              ),
              value: receiptCameraMock,
              onChanged: (v) {
                ref.read(debugReceiptCameraMockProvider.notifier).state = v;
                _setStatus(
                  v
                      ? 'Mock camera ON — open expense → Camera'
                      : 'Mock camera OFF',
                );
              },
            ),

            const _SectionHeader('Tools'),
            _DebugAction(
              icon: Icons.system_update_outlined,
              label: 'Force upgrade dialog',
              subtitle: 'Clears stored timestamps, sets displayAlways=true',
              onTap: () => unawaited(_forceUpgradeDialog()),
            ),
            _DebugAction(
              icon: Icons.sync,
              label: 'Trigger data sync',
              onTap: () => unawaited(_triggerSync()),
            ),
            _DebugAction(
              icon: Icons.restart_alt,
              label: 'Reset onboarding',
              subtitle: 'Shows onboarding flow on next restart',
              onTap: _resetOnboarding,
            ),
            _DebugAction(
              icon: Icons.link,
              label: 'Open invite by token',
              subtitle: 'Paste token to test invite flow',
              onTap: () => unawaited(_openInviteByToken()),
            ),
            _DebugAction(
              icon: Icons.error_outline,
              label: 'Show error UI',
              subtitle: 'Opens error content (Share/Report)',
              onTap: _showErrorUI,
            ),

            _SectionHeader('debug_sync_status_override'.tr()),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final entry in const [
                  (SyncStatus.connected, 'Connected'),
                  (SyncStatus.syncing, 'Syncing'),
                  (SyncStatus.offline, 'Offline'),
                  (SyncStatus.localOnly, 'Local only'),
                ])
                  FilterChip(
                    label: Text(entry.$2),
                    selected: syncOverride == entry.$1,
                    onSelected: (_) {
                      ref.read(debugSyncStatusOverrideProvider.notifier).state =
                          entry.$1;
                    },
                  ),
                FilterChip(
                  label: const Text('Clear'),
                  selected: syncOverride == null,
                  onSelected: (_) {
                    ref.read(debugSyncStatusOverrideProvider.notifier).state =
                        null;
                  },
                ),
              ],
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForCelebration(CelebrationKind kind) {
    return switch (kind) {
      CelebrationKind.firstExpense => Icons.park_outlined,
      CelebrationKind.newExpense => Icons.eco_outlined,
      CelebrationKind.settlement => Icons.water_drop_outlined,
      CelebrationKind.personJoined => Icons.spa_outlined,
      CelebrationKind.personLeft => Icons.cloud_outlined,
      CelebrationKind.newGroup => Icons.groups_outlined,
      CelebrationKind.newPersonalList => Icons.dark_mode_outlined,
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugAction extends StatelessWidget {
  const _DebugAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onTap,
    );
  }
}
