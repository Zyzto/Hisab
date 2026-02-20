import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';

import '../database/database_providers.dart';
import '../navigation/route_paths.dart';
import '../services/connectivity_service.dart';
import '../../features/settings/providers/settings_framework_providers.dart';
import '../../features/settings/settings_definitions.dart';

/// Resolves to true when the running package name contains `.debug`
/// (i.e. the Android debug variant with applicationIdSuffix = ".debug").
/// Returns false on release / profile builds or web.
final isDebugBuildProvider = FutureProvider<bool>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.packageName.contains('.debug');
  } catch (_) {
    return false;
  }
});

/// Small floating bug-icon button shown only on debug builds.
/// Tap it to open [_DebugMenuSheet].
///
/// [navigatorContext] must be a context that has a [Navigator] ancestor
/// (e.g. [GoRouterState.navigatorKey.currentContext]). The FAB is built
/// in the app builder, which is not under the router's Navigator.
///
/// [localeContext] must be a context that has [EasyLocalization] (e.g. the
/// MaterialApp.router builder context). The modal sheet is built in the
/// navigator overlay, which may not see EasyLocalization; wrapping the
/// sheet in EasyLocalization with this context's locale avoids
/// "Localization not found for current context".
///
/// [onBeforeOpen] is called when the FAB is tapped, before showing the sheet
/// (e.g. to hide the FAB). [whenSheetClosed] is called when the sheet is
/// dismissed (e.g. to show the FAB again).
class DebugMenuFab extends ConsumerWidget {
  const DebugMenuFab({
    super.key,
    required this.upgrader,
    required this.navigatorContext,
    required this.localeContext,
    this.onBeforeOpen,
    this.whenSheetClosed,
  });

  final Upgrader upgrader;
  final BuildContext? navigatorContext;
  final BuildContext? localeContext;
  final VoidCallback? onBeforeOpen;
  final VoidCallback? whenSheetClosed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.small(
      heroTag: 'debugMenuFab',
      tooltip: 'Debug menu',
      backgroundColor:
          Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.9),
      foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
      onPressed: () {
        final navContext = navigatorContext;
        final locContext = localeContext;
        if (navContext != null &&
            navContext.mounted &&
            locContext != null &&
            locContext.mounted) {
          onBeforeOpen?.call();
          showModalBottomSheet<void>(
            context: navContext,
            isScrollControlled: true,
            builder: (_) => EasyLocalization(
              supportedLocales: const [Locale('en'), Locale('ar')],
              path: 'assets/translations',
              fallbackLocale: const Locale('en'),
              startLocale: locContext.locale,
              child: _DebugMenuSheet(upgrader: upgrader),
            ),
          ).then((_) => whenSheetClosed?.call());
        }
      },
      child: const Icon(Icons.bug_report_outlined, size: 20),
    );
  }
}

class _DebugMenuSheet extends ConsumerStatefulWidget {
  const _DebugMenuSheet({required this.upgrader});

  final Upgrader upgrader;

  @override
  ConsumerState<_DebugMenuSheet> createState() => _DebugMenuSheetState();
}

class _DebugMenuSheetState extends ConsumerState<_DebugMenuSheet> {
  String? _statusMessage;

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  Future<void> _forceUpgradeDialog() async {
    await Upgrader.clearSavedSettings();
    widget.upgrader.updateState(
      widget.upgrader.state.copyWith(debugDisplayAlways: true),
    );
    if (mounted) Navigator.of(context).pop();
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
    ref
        .read(settings.provider(onboardingCompletedSettingDef).notifier)
        .set(false);
    _setStatus('Onboarding reset — restart the app');
  }

  void _openInviteByToken() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open invite by token'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Paste invite token',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            final token = controller.text.trim();
            if (token.isNotEmpty) {
              context.go(RoutePaths.inviteAccept(token));
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final token = controller.text.trim();
              if (token.isEmpty) return;
              context.go(RoutePaths.inviteAccept(token));
              Navigator.of(ctx).pop();
            },
            child: const Text('Open'),
          ),
        ],
      ),
    ).then((_) {
      controller.dispose();
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                Icon(Icons.bug_report_outlined,
                    color: colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Debug Menu',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // App info
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final info = snap.data!;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Package', value: info.packageName),
                      _InfoRow(
                          label: 'Version',
                          value:
                              '${info.version} (${info.buildNumber})'),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Actions
            _DebugAction(
              icon: Icons.system_update_outlined,
              label: 'Force upgrade dialog',
              subtitle: 'Clears stored timestamps, sets displayAlways=true',
              onTap: _forceUpgradeDialog,
            ),
            _DebugAction(
              icon: Icons.sync,
              label: 'Trigger data sync',
              onTap: _triggerSync,
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
              subtitle: 'Paste token to test invite flow in debug',
              onTap: _openInviteByToken,
            ),

            // Sync status override (for testing chip/banner)
            const SizedBox(height: 8),
            Text(
              'Sync status (override)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _SyncStatusChip(
                  label: 'Connected',
                  onTap: () => ref
                      .read(debugSyncStatusOverrideProvider.notifier)
                      .state = SyncStatus.connected,
                ),
                _SyncStatusChip(
                  label: 'Syncing',
                  onTap: () => ref
                      .read(debugSyncStatusOverrideProvider.notifier)
                      .state = SyncStatus.syncing,
                ),
                _SyncStatusChip(
                  label: 'Offline',
                  onTap: () => ref
                      .read(debugSyncStatusOverrideProvider.notifier)
                      .state = SyncStatus.offline,
                ),
                _SyncStatusChip(
                  label: 'Local only',
                  onTap: () => ref
                      .read(debugSyncStatusOverrideProvider.notifier)
                      .state = SyncStatus.localOnly,
                ),
                _SyncStatusChip(
                  label: 'Clear',
                  onTap: () =>
                      ref.read(debugSyncStatusOverrideProvider.notifier).state =
                          null,
                ),
              ],
            ),

            // Status feedback
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
            width: 72,
            child: Text(label,
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
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

class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: false,
      onSelected: (_) => onTap(),
    );
  }
}
