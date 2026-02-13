import 'dart:async';
import 'dart:convert';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../constants/supabase_config.dart';
import '../services/connectivity_service.dart';
import '../../features/settings/providers/settings_framework_providers.dart';

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

      await _pushPendingWrites(db, client);
      await _fetchAll(db, client);

      Log.info('DataSyncService: sync complete');
    } catch (e, st) {
      Log.error('DataSyncService: sync failed', error: e, stackTrace: st);
    } finally {
      _isSyncing = false;
      final syncStatus = ref.read(syncStatusProvider.notifier);
      syncStatus.setSynced();
    }
  }

  /// Push queued offline writes to Supabase.
  Future<void> _pushPendingWrites(
    PowerSyncDatabase db,
    SupabaseClient client,
  ) async {
    final rows = await db.getAll(
      'SELECT * FROM pending_writes ORDER BY created_at ASC',
    );
    if (rows.isEmpty) return;

    Log.info('DataSyncService: pushing ${rows.length} pending writes');
    for (final row in rows) {
      try {
        final tableName = row['table_name'] as String;
        final operation = row['operation'] as String;
        final rowId = row['row_id'] as String;
        final dataJson = row['data_json'] as String?;
        final data = dataJson != null
            ? jsonDecode(dataJson) as Map<String, dynamic>
            : null;

        final table = client.from(tableName);
        switch (operation) {
          case 'insert':
            if (data != null) await table.upsert(data);
            break;
          case 'update':
            if (data != null) await table.update(data).eq('id', rowId);
            break;
          case 'delete':
            await table.delete().eq('id', rowId);
            break;
        }

        // Remove from queue on success
        await db.execute('DELETE FROM pending_writes WHERE id = ?', [
          row['id'],
        ]);
      } catch (e, st) {
        Log.warning(
          'DataSyncService: failed to push pending write ${row['id']}',
          error: e,
          stackTrace: st,
        );
        // Stop processing further; will retry next sync cycle
        break;
      }
    }
  }

  /// Full fetch from Supabase → replace local cache.
  /// Uses INSERT OR REPLACE (upsert) so watch() streams emit updates.
  Future<void> _fetchAll(PowerSyncDatabase db, SupabaseClient client) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    // Fetch groups the user is a member of
    final memberRows = await client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);
    final groupIds = memberRows
        .map<String>((r) => r['group_id'] as String)
        .toList();

    if (groupIds.isEmpty) {
      Log.debug('DataSyncService: user has no groups, clearing local cache');
      await db.execute('DELETE FROM groups');
      await db.execute('DELETE FROM group_members');
      await db.execute('DELETE FROM participants');
      await db.execute('DELETE FROM expenses');
      await db.execute('DELETE FROM expense_tags');
      await db.execute('DELETE FROM group_invites');
      await db.execute('DELETE FROM invite_usages');
      return;
    }

    // Fetch all related data
    final groups = await client
        .from('groups')
        .select()
        .inFilter('id', groupIds);
    final members = await client
        .from('group_members')
        .select()
        .inFilter('group_id', groupIds);
    final participants = await client
        .from('participants')
        .select()
        .inFilter('group_id', groupIds);
    final expenses = await client
        .from('expenses')
        .select()
        .inFilter('group_id', groupIds);
    final tags = await client
        .from('expense_tags')
        .select()
        .inFilter('group_id', groupIds);
    final invites = await client
        .from('group_invites')
        .select()
        .inFilter('group_id', groupIds);

    // Collect invite IDs to fetch usages
    final inviteIds = invites
        .map<String>((r) => r['id'] as String)
        .toList();
    final List<dynamic> inviteUsages = inviteIds.isNotEmpty
        ? await client
            .from('invite_usages')
            .select()
            .inFilter('invite_id', inviteIds)
        : [];

    // Write to local DB in a batch
    await db.writeTransaction((tx) async {
      // Clear existing data for these groups
      for (final gid in groupIds) {
        await tx.execute('DELETE FROM group_members WHERE group_id = ?', [gid]);
        await tx.execute('DELETE FROM participants WHERE group_id = ?', [gid]);
        await tx.execute('DELETE FROM expenses WHERE group_id = ?', [gid]);
        await tx.execute('DELETE FROM expense_tags WHERE group_id = ?', [gid]);
        await tx.execute('DELETE FROM group_invites WHERE group_id = ?', [gid]);
      }
      // Clear invite usages for these invites (cascade via group)
      await tx.execute('DELETE FROM invite_usages');
      // Remove groups that are in our set, plus any local groups no longer in the set
      await tx.execute('DELETE FROM groups');

      // Re-insert fresh data
      for (final g in groups) {
        await tx.execute(
          '''INSERT INTO groups (id, name, currency_code, owner_id, settlement_method,
            treasurer_participant_id, settlement_freeze_at, settlement_snapshot_json,
            allow_member_add_expense, allow_member_change_settings,
            created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            g['id'],
            g['name'],
            g['currency_code'],
            g['owner_id'],
            g['settlement_method'],
            g['treasurer_participant_id'],
            g['settlement_freeze_at'],
            g['settlement_snapshot_json'],
            g['allow_member_add_expense'] == true ? 1 : 0,
            g['allow_member_change_settings'] == true ? 1 : 0,
            g['created_at'],
            g['updated_at'],
          ],
        );
      }
      for (final m in members) {
        await tx.execute(
          'INSERT INTO group_members (id, group_id, user_id, role, participant_id, joined_at) VALUES (?, ?, ?, ?, ?, ?)',
          [
            m['id'],
            m['group_id'],
            m['user_id'],
            m['role'],
            m['participant_id'],
            m['joined_at'],
          ],
        );
      }
      for (final p in participants) {
        await tx.execute(
          'INSERT INTO participants (id, group_id, name, sort_order, user_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            p['id'],
            p['group_id'],
            p['name'],
            p['sort_order'],
            p['user_id'],
            p['created_at'],
            p['updated_at'],
          ],
        );
      }
      for (final e in expenses) {
        await tx.execute(
          '''INSERT INTO expenses (id, group_id, payer_participant_id, amount_cents,
            currency_code, title, description, date, split_type, split_shares_json,
            type, to_participant_id, tag, line_items_json, receipt_image_path,
            created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            e['id'],
            e['group_id'],
            e['payer_participant_id'],
            e['amount_cents'],
            e['currency_code'],
            e['title'],
            e['description'],
            e['date'],
            e['split_type'],
            e['split_shares_json'] is String
                ? e['split_shares_json']
                : jsonEncode(e['split_shares_json']),
            e['type'],
            e['to_participant_id'],
            e['tag'],
            e['line_items_json'] is String
                ? e['line_items_json']
                : (e['line_items_json'] != null
                      ? jsonEncode(e['line_items_json'])
                      : null),
            e['receipt_image_path'],
            e['created_at'],
            e['updated_at'],
          ],
        );
      }
      for (final t in tags) {
        await tx.execute(
          'INSERT INTO expense_tags (id, group_id, label, icon_name, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
          [
            t['id'],
            t['group_id'],
            t['label'],
            t['icon_name'],
            t['created_at'],
            t['updated_at'],
          ],
        );
      }
      for (final inv in invites) {
        await tx.execute(
          '''INSERT INTO group_invites (id, group_id, token, invitee_email, role,
            created_at, expires_at, created_by, label, max_uses, use_count, is_active)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            inv['id'],
            inv['group_id'],
            inv['token'],
            inv['invitee_email'],
            inv['role'],
            inv['created_at'],
            inv['expires_at'],
            inv['created_by'],
            inv['label'],
            inv['max_uses'],
            inv['use_count'] ?? 0,
            inv['is_active'] == true ? 1 : 0,
          ],
        );
      }
      for (final usage in inviteUsages) {
        await tx.execute(
          'INSERT INTO invite_usages (id, invite_id, user_id, accepted_at) VALUES (?, ?, ?, ?)',
          [
            usage['id'],
            usage['invite_id'],
            usage['user_id'],
            usage['accepted_at'],
          ],
        );
      }
    });

    Log.debug(
      'DataSyncService: fetched ${groups.length} groups, '
      '${participants.length} participants, ${expenses.length} expenses',
    );
  }
}
