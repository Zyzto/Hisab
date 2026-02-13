import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/connectivity_service.dart';

/// Animated chip that shows the current sync status.
/// Shows icon + label, with smooth transitions between states.
/// Connected state auto-collapses to icon-only after 2 seconds.
/// Hidden in Local-Only mode.
class SyncStatusChip extends ConsumerStatefulWidget {
  const SyncStatusChip({super.key});

  @override
  ConsumerState<SyncStatusChip> createState() => _SyncStatusChipState();
}

class _SyncStatusChipState extends ConsumerState<SyncStatusChip> {
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
      if (mounted) {
        setState(() => _showLabel = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider);

    // Detect status changes to reset label visibility.
    if (status != _previousStatus) {
      _collapseTimer?.cancel();
      _showLabel = true;
      _previousStatus = status;

      // Auto-collapse only for connected state.
      if (status == SyncStatus.connected) {
        _scheduleCollapse();
      }
    }

    if (status == SyncStatus.localOnly) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final chipData = _chipData(status, colorScheme);

    return GestureDetector(
      onTap: () => _showStatusSnackBar(context, status),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: AnimatedContainer(
          key: ValueKey('${status.name}_$_showLabel'),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: _showLabel ? 10 : 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: chipData.backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(status, chipData),
              if (_showLabel) ...[
                const SizedBox(width: 6),
                Text(
                  chipData.label,
                  style: TextStyle(
                    color: chipData.foregroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(SyncStatus status, _ChipData data) {
    if (status == SyncStatus.syncing) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: data.foregroundColor,
        ),
      );
    }
    return Icon(data.icon, size: 20, color: data.foregroundColor);
  }

  _ChipData _chipData(SyncStatus status, ColorScheme cs) {
    // Use onXxxContainer / xxxContainer pairs for guaranteed contrast
    // across all themes (light, dark, AMOLED, custom seed colors).
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
