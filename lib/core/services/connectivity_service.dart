import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/settings/providers/settings_framework_providers.dart';

part 'connectivity_service.g.dart';

/// Debug-only: when non-null, UI shows this instead of real sync status.
/// Set from debug menu to test chip/banner for each status.
final debugSyncStatusOverrideProvider =
    StateProvider<SyncStatus?>((ref) => null);

/// Sync status exposed to the UI for the connection status icon.
enum SyncStatus {
  /// Local-Only mode — no icon shown.
  localOnly,

  /// Online mode, connected and idle.
  connected,

  /// Online mode, actively syncing (fetch/push).
  syncing,

  /// Online mode, no network connectivity.
  offline,

  /// Online mode, last sync failed (auth or after retries).
  syncFailed,
}

/// Whether the device currently has network connectivity.
/// In Local-Only mode this still reflects real connectivity
/// but is unused by repositories.
@Riverpod(keepAlive: true)
class ConnectivityNotifier extends _$ConnectivityNotifier {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  bool build() {
    _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (state != online) {
        Log.debug('Connectivity changed: ${online ? "online" : "offline"}');
        state = online;
      }
    });
    ref.onDispose(() => _sub?.cancel());

    // Assume online initially; the stream will correct quickly.
    return true;
  }
}

/// Whether the app can currently reach Supabase for writes.
/// Returns `true` if:
///   - The user is in Local-Only mode (no restrictions), OR
///   - The user is in Online mode AND has network connectivity.
@riverpod
bool canWriteOnline(Ref ref) {
  final localOnly = ref.watch(effectiveLocalOnlyProvider);
  if (localOnly) return true; // Local-Only: everything allowed
  return ref.watch(connectivityProvider);
}

/// High-level sync status for the UI status icon.
@Riverpod(keepAlive: true)
class SyncStatusNotifier extends _$SyncStatusNotifier {
  @override
  SyncStatus build() {
    final localOnly = ref.watch(effectiveLocalOnlyProvider);
    if (localOnly) return SyncStatus.localOnly;

    final hasNetwork = ref.watch(connectivityProvider);
    if (!hasNetwork) return SyncStatus.offline;

    return SyncStatus.connected;
  }

  /// Call when a sync operation starts.
  void setSyncing() {
    if (state != SyncStatus.localOnly) {
      state = SyncStatus.syncing;
    }
  }

  /// Call when a sync operation completes successfully.
  void setSynced() {
    if (state == SyncStatus.syncing || state == SyncStatus.syncFailed) {
      final hasNetwork = ref.read(connectivityProvider);
      state = hasNetwork ? SyncStatus.connected : SyncStatus.offline;
    }
  }

  /// Call when sync failed (auth error or after retries). Next successful
  /// sync or connectivity change will clear this.
  void setSyncFailed() {
    if (state == SyncStatus.syncing) {
      state = SyncStatus.syncFailed;
    }
  }
}

/// Sync status shown in UI; respects [debugSyncStatusOverrideProvider] when set.
@Riverpod(keepAlive: true)
SyncStatus syncStatusForDisplay(Ref ref) {
  final override = ref.watch(debugSyncStatusOverrideProvider);
  if (override != null) return override;
  return ref.watch(syncStatusProvider);
}
