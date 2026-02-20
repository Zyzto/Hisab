import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/connectivity_service.dart';

/// Animated chip that shows the current sync status.
/// Icon-only: circle. With label: rounded rectangle. Transitions are animated.
/// Connected state auto-collapses to icon-only after 2 seconds.
/// Hidden in Local-Only mode.
class SyncStatusChip extends ConsumerStatefulWidget {
  const SyncStatusChip({super.key});

  @override
  ConsumerState<SyncStatusChip> createState() => _SyncStatusChipState();
}

class _SyncStatusChipState extends ConsumerState<SyncStatusChip> {
  static const _duration = Duration(milliseconds: 250);
  static const _minWidthForLabel = 70.0;
  static const _compactSize = 36.0;
  static const _roundedRectRadius = 16.0;

  Timer? _collapseTimer;
  bool _showLabel = true;
  SyncStatus? _previousStatus;

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showLabel = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusForDisplayProvider);

    if (status != _previousStatus) {
      _collapseTimer?.cancel();
      _showLabel = true;
      _previousStatus = status;
      if (status == SyncStatus.connected) _scheduleCollapse();
    }

    if (status == SyncStatus.localOnly) {
      return const SizedBox.shrink();
    }

    final data = _chipData(status, Theme.of(context).colorScheme);

    return GestureDetector(
      onTap: () => _showStatusSnackBar(context, status),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showLabel =
                _showLabel && constraints.maxWidth >= _minWidthForLabel;
            final isCompact = !showLabel;
            // Fit circle in the leading slot (e.g. some AppBars give only 32px height).
            final compactSize = isCompact
                ? _compactSize
                    .clamp(0.0, constraints.maxWidth)
                    .clamp(0.0, constraints.maxHeight)
                : _compactSize;

            final chip = AnimatedContainer(
              key: ValueKey('${status.name}_$showLabel'),
              duration: _duration,
              curve: Curves.easeInOut,
              width: isCompact ? compactSize : null,
              height: isCompact ? compactSize : null,
              padding: isCompact
                  ? EdgeInsets.all(compactSize > 28 ? 6 : 4)
                  : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: data.backgroundColor,
                borderRadius: BorderRadius.circular(
                  isCompact ? compactSize / 2 : _roundedRectRadius,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIcon(status, data),
                  if (showLabel) ...[
                    const SizedBox(width: 6),
                    Text(
                      data.label,
                      style: TextStyle(
                        color: data.foregroundColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            );

            return AnimatedSize(
              duration: _duration,
              curve: Curves.easeInOut,
              child: isCompact
                  ? UnconstrainedBox(
                      child: SizedBox(
                        width: compactSize,
                        height: compactSize,
                        child: chip,
                      ),
                    )
                  : chip,
            );
          },
        ),
      ),
    );
  }

  Widget _buildIcon(SyncStatus status, _ChipData data) {
    const size = 20.0;
    if (status == SyncStatus.syncing) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: data.foregroundColor,
        ),
      );
    }
    return Icon(data.icon, size: size, color: data.foregroundColor);
  }

  _ChipData _chipData(SyncStatus status, ColorScheme cs) {
    return switch (status) {
      SyncStatus.connected => _ChipData(
        icon: Icons.cloud_done_outlined,
        label: 'sync_connected'.tr(),
        foregroundColor: cs.onPrimaryContainer,
        backgroundColor: cs.primaryContainer,
      ),
      SyncStatus.syncing => _ChipData(
        icon: Icons.sync,
        label: 'sync_syncing'.tr(),
        foregroundColor: cs.onTertiaryContainer,
        backgroundColor: cs.tertiaryContainer,
      ),
      SyncStatus.offline => _ChipData(
        icon: Icons.cloud_off_outlined,
        label: 'sync_offline'.tr(),
        foregroundColor: cs.onErrorContainer,
        backgroundColor: cs.errorContainer,
      ),
      SyncStatus.localOnly => _ChipData(
        icon: Icons.storage,
        label: '',
        foregroundColor: cs.onSurfaceVariant,
        backgroundColor: Colors.transparent,
      ),
    };
  }

  void _showStatusSnackBar(BuildContext context, SyncStatus status) {
    final message = switch (status) {
      SyncStatus.connected => 'sync_data_auto'.tr(),
      SyncStatus.syncing => 'sync_data_uploading'.tr(),
      SyncStatus.offline => 'sync_offline_banner'.tr(),
      SyncStatus.localOnly => '',
    };
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _ChipData {
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const _ChipData({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });
}
