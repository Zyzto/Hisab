import 'dart:async';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../constants/supabase_config.dart';
import '../services/connectivity_service.dart';
import '../../features/settings/providers/settings_framework_providers.dart';
import 'sync_engine.dart';

part 'database_providers.g.dart';

/// The PowerSync database instance. Always available (local SQLite).
/// Initialized in main.dart and overridden in ProviderScope.
@Riverpod(keepAlive: true)
PowerSyncDatabase powerSyncDatabase(Ref ref) {
  throw UnimplementedError(
    'Override powerSyncDatabaseProvider in ProviderScope',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DataSyncService — replaces the old PowerSync Cloud SyncManager.
//
// Responsibilities:
//   1. Full fetch from Supabase → populate local SQLite cache
//   2. Push pending_writes queue when connectivity returns
//   3. Periodic refresh (~5 min) to pick up remote changes
//   4. Does nothing in Local-Only mode
// ─────────────────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
class DataSyncService extends _$DataSyncService {
  Timer? _refreshTimer;
  bool _isSyncing = false;

  @override
  void build() {
    final localOnly = ref.watch(effectiveLocalOnlyProvider);
    if (localOnly || !supabaseConfigAvailable) {
      _refreshTimer?.cancel();
      Log.debug('DataSyncService: inactive (localOnly=$localOnly)');
      return;
    }

    final isAuth = ref.watch(isAuthenticatedProvider);
    final hasNetwork = ref.watch(connectivityProvider);

    if (!isAuth) {
      _refreshTimer?.cancel();
      Log.debug('DataSyncService: inactive (not authenticated)');
      return;
    }

    if (hasNetwork) {
      // Defer initial sync so we don't modify syncStatusProvider during build
      // (Riverpod forbids modifying other providers while a provider is building).
      Future.microtask(() => _syncNow());

      // Periodic refresh every 5 minutes
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _syncNow(),
      );
    } else {
      _refreshTimer?.cancel();
      Log.debug('DataSyncService: offline, waiting for connectivity');
    }

    ref.onDispose(() {
      _refreshTimer?.cancel();
    });
  }

  /// Trigger an immediate sync (push pending + full fetch).
  Future<void> syncNow() => _syncNow();

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final syncStatus = ref.read(syncStatusProvider.notifier);
    syncStatus.setSyncing();

    try {
      final db = ref.read(powerSyncDatabaseProvider);
      final client = Supabase.instance.client;

      final engine = SyncEngine();
      final pendingRows = await db.getAll(
        'SELECT * FROM pending_writes ORDER BY created_at ASC',
      );
      if (pendingRows.isNotEmpty) {
        Log.info('DataSyncService: pushing ${pendingRows.length} pending writes');
      }
      await engine.pushPendingWrites(db, client);
      await engine.fetchAll(db, client);

      Log.info('DataSyncService: sync complete');
    } catch (e, st) {
      Log.error('DataSyncService: sync failed', error: e, stackTrace: st);
    } finally {
      _isSyncing = false;
      final syncStatus = ref.read(syncStatusProvider.notifier);
      syncStatus.setSynced();
    }
  }
}
