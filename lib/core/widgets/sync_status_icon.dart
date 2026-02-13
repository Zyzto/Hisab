import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/connectivity_service.dart';

/// Small icon that shows the current sync status.
/// Only visible in Online mode; hidden in Local-Only.
class SyncStatusIcon extends ConsumerWidget {
  const SyncStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);

    return switch (status) {
      SyncStatus.localOnly => const SizedBox.shrink(),
      SyncStatus.connected => Tooltip(
        message: 'sync_connected'.tr(),
        child: Icon(
          Icons.cloud_done_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      SyncStatus.syncing => Tooltip(
        message: 'sync_syncing'.tr(),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ),
      ),
      SyncStatus.offline => Tooltip(
        message: 'sync_offline'.tr(),
        child: Icon(
          Icons.cloud_off_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    };
  }
}
