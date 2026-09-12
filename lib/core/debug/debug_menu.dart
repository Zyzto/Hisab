import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/expenses/camera/receipt_camera_debug.dart';
import '../celebration/celebration_controller.dart';
import '../celebration/celebration_dedupe.dart';
import '../celebration/celebration_kind.dart';
import '../layout/responsive_sheet.dart';
import '../platform/ui_perf.dart';
import '../settings/providers/settings_framework_providers.dart';
import '../settings/settings_definitions.dart';
import '../widgets/error_content.dart';
import 'integration_test_mode.dart';

final packageIsDebugBuildProvider = FutureProvider<bool>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.packageName.contains('.debug');
  } catch (_) {
    return false;
  }
});

final showDebugMenuProvider = Provider<bool>((ref) {
  if (isIntegrationTestMode) return false;
  if (kDebugMode) return true;
  return ref.watch(packageIsDebugBuildProvider).asData?.value ?? false;
});

/// Small debug-only button. A long press drags it; a normal tap opens the
/// local developer menu for local diagnostics and test controls.
class DebugMenuFab extends StatefulWidget {
  const DebugMenuFab({
    super.key,
    required this.navigatorKey,
    required this.localeContext,
    this.onBeforeOpen,
    this.whenSheetClosed,
    this.onDragDelta,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final BuildContext? localeContext;
  final VoidCallback? onBeforeOpen;
  final VoidCallback? whenSheetClosed;
  final ValueChanged<Offset>? onDragDelta;

  @override
  State<DebugMenuFab> createState() => _DebugMenuFabState();
}

class _DebugMenuFabState extends State<DebugMenuFab> {
  Offset _lastDragOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _lastDragOffset = Offset.zero,
      onLongPressMoveUpdate: (details) {
        final next = details.offsetFromOrigin;
        final delta = next - _lastDragOffset;
        _lastDragOffset = next;
        if (delta != Offset.zero) widget.onDragDelta?.call(delta);
      },
      child: FloatingActionButton.small(
        heroTag: 'debugMenuFab',
        tooltip: 'debug_menu_title'.tr(),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.9),
        foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
        onPressed: () {
          final navContext = widget.navigatorKey.currentContext;
          final localeContext = widget.localeContext;
          if (navContext == null ||
              !navContext.mounted ||
              localeContext == null ||
              !localeContext.mounted) {
            return;
          }
          widget.onBeforeOpen?.call();
          showResponsiveSheet<void>(
            context: navContext,
            title: 'debug_menu_title'.tr(),
            isScrollControlled: true,
            centerInFullViewport: false,
            child: EasyLocalization(
              supportedLocales: const [Locale('en'), Locale('ar')],
              path: 'assets/translations',
              fallbackLocale: const Locale('en'),
              startLocale: localeContext.locale,
              child: _DebugMenuSheet(hostContext: navContext),
            ),
          ).whenComplete(() => widget.whenSheetClosed?.call());
        },
        child: const Icon(Icons.bug_report_outlined, size: 20),
      ),
    );
  }
}

class _DebugMenuSheet extends ConsumerStatefulWidget {
  const _DebugMenuSheet({required this.hostContext});

  final BuildContext hostContext;

  @override
  ConsumerState<_DebugMenuSheet> createState() => _DebugMenuSheetState();
}

class _DebugMenuSheetState extends ConsumerState<_DebugMenuSheet> {
  String? _statusMessage;
  late final Future<PackageInfo> _packageInfo;

  static const _celebrationLabels = <CelebrationKind, String>{
    CelebrationKind.firstExpense: 'Forest — first expense',
    CelebrationKind.newExpense: 'Plants — new expense',
    CelebrationKind.settlement: 'Sea — settlement',
    CelebrationKind.personJoined: 'Jungle — person joined',
    CelebrationKind.personLeft: 'Sky — person left',
    CelebrationKind.newGroup: 'Grove — new group',
    CelebrationKind.newPersonalList: 'Dusk — new personal list',
  };

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  void _setStatus(String value) {
    if (mounted) setState(() => _statusMessage = value);
  }

  Future<void> _resetOnboarding() async {
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings == null) {
      _setStatus('Settings are not available');
      return;
    }
    await ref
        .read(settings.provider(onboardingCompletedSettingDef).notifier)
        .set(false);
    _setStatus('Onboarding reset — restart the app');
  }

  Future<void> _setCameraMock(bool enabled) async {
    ref.read(debugReceiptCameraMockProvider.notifier).state = enabled;
    _setStatus(enabled ? 'Receipt camera mock enabled' : 'Receipt camera mock disabled');
  }

  Future<void> _setExtraAnimations(bool enabled) async {
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings == null) return;
    await ref
        .read(settings.provider(extraAnimationsEnabledSettingDef).notifier)
        .set(enabled);
    _setStatus(enabled ? 'Extra animations enabled' : 'Extra animations disabled');
  }

  Future<void> _clearCelebrationDedupe() async {
    await CelebrationDedupe.instance.debugClearAll();
    _setStatus('Celebration history cleared');
  }

  void _showErrorUi() {
    showResponsiveSheet<void>(
      context: context,
      title: 'Error (debug)',
      isScrollControlled: true,
      centerInFullViewport: false,
      child: Builder(
        builder: (sheetContext) => SingleChildScrollView(
          child: ErrorContentWidget(
            message: 'Sample error for testing the error UI.',
            onRetry: () => Navigator.of(sheetContext).pop(),
            details: 'Debug-triggered sample error.',
          ),
        ),
      ),
    );
  }

  Future<void> _playCelebration(CelebrationKind kind) async {
    final bus = ref.read(celebrationControllerProvider);
    Navigator.of(context, rootNavigator: true).pop();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (widget.hostContext.mounted) bus.request(kind);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cameraMock = ref.watch(debugReceiptCameraMockProvider);
    final extraAnimations = ref.watch(extraAnimationsEnabledProvider);

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
              future: _packageInfo,
              builder: (context, snapshot) {
                final info = snapshot.data;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        label: 'Package',
                        value: info?.packageName ?? 'debug',
                      ),
                      if (info != null)
                        _InfoRow(
                          label: 'Version',
                          value: '${info.version} (${info.buildNumber})',
                        ),
                      const _InfoRow(
                        label: 'Storage',
                        value: 'Local device only',
                      ),
                      _InfoRow(
                        label: 'Reduced motion',
                        value: UiPerf.preferReducedChromeMotion ? 'yes' : 'no',
                      ),
                    ],
                  ),
                );
              },
            ),
            const _SectionHeader('Local developer tools'),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Receipt camera mock'),
              subtitle: const Text('Use the animated camera preview'),
              value: cameraMock,
              onChanged: _setCameraMock,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Extra animations'),
              value: extraAnimations,
              onChanged: _setExtraAnimations,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restart_alt),
              title: const Text('Reset onboarding'),
              onTap: _resetOnboarding,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Clear celebration history'),
              onTap: _clearCelebrationDedupe,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.error_outline),
              title: const Text('Show error UI'),
              onTap: _showErrorUi,
            ),
            const _SectionHeader('Celebrations'),
            for (final entry in _celebrationLabels.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                trailing: const Icon(Icons.play_arrow),
                onTap: () => _playCelebration(entry.key),
              ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('$label: $value'),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}
