import 'dart:convert';

import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_backend.dart';

/// Testable sync operations: full fetch from Supabase into local DB,
/// and push of pending_writes to Supabase. Used by [DataSyncService].
class SyncEngine {
  /// Push queued offline writes to Supabase.
  Future<void> pushPendingWrites(
    PowerSyncDatabase db,
    SupabaseClient client,
  ) async {
    await pushPendingWritesWithBackend(db, SupabaseSyncBackend(client));
  }

  /// Push queued offline writes using [SyncBackend]. Used for testing.
  Future<void> pushPendingWritesWithBackend(
    PowerSyncDatabase db,
    SyncBackend backend,
  ) async {
    final rows = await db.getAll(
      'SELECT * FROM pending_writes ORDER BY created_at ASC',
    );
    if (rows.isEmpty) return;

    for (final row in rows) {
      final tableName = row['table_name'] as String;
      final operation = row['operation'] as String;
      final rowId = row['row_id'] as String;
      final dataJson = row['data_json'] as String?;
      final data = dataJson != null
          ? jsonDecode(dataJson) as Map<String, dynamic>
          : null;

      switch (operation) {
        case 'insert':
          if (data != null) await backend.upsert(tableName, data);
          break;
        case 'update':
          if (data != null) await backend.update(tableName, data, rowId);
          break;
        case 'delete':
          await backend.delete(tableName, rowId);
          break;
      }

      await db.execute('DELETE FROM pending_writes WHERE id = ?', [
        row['id'],
      ]);
    }
  }

  /// Full fetch from Supabase into local DB. Replaces local cache for
  /// groups the current user is a member of.
  Future<void> fetchAll(
    PowerSyncDatabase db,
    SupabaseClient client,
  ) async {
    await fetchAllWithBackend(db, SupabaseSyncBackend(client));
  }

  /// Full fetch using [SyncBackend]. Used for testing.
  Future<void> fetchAllWithBackend(
    PowerSyncDatabase db,
    SyncBackend backend,
  ) async {
    final userId = backend.currentUserId;
    if (userId == null) return;

    final memberRows = await backend.getGroupIdsForUser(userId);
    final groupIds =
        memberRows.map<String>((r) => r['group_id'] as String).toList();

    if (groupIds.isEmpty) {
      await db.execute('DELETE FROM groups');
      await db.execute('DELETE FROM group_members');
      await db.execute('DELETE FROM participants');
      await db.execute('DELETE FROM expenses');
      await db.execute('DELETE FROM expense_tags');
      await db.execute('DELETE FROM group_invites');
      await db.execute('DELETE FROM invite_usages');
      return;
    }

    final groups = await backend.getGroups(groupIds);
    final members = await backend.getMembers(groupIds);
    final participants = await backend.getParticipants(groupIds);
    final expenses = await backend.getExpenses(groupIds);
    final tags = await backend.getTags(groupIds);
    final invites = await backend.getInvites(groupIds);

    final inviteIds = invites.map<String>((r) => r['id'] as String).toList();
    final inviteUsages = await backend.getInviteUsages(inviteIds);

    await db.writeTransaction((tx) async {
      for (final gid in groupIds) {
        await tx.execute('DELETE FROM group_members WHERE group_id = ?', [gid]);
        await tx.execute('DELETE FROM participants WHERE group_id = ?', [gid]);
        await tx.execute('DELETE FROM expenses WHERE group_id = ?', [gid]);
        await tx.execute('DELETE FROM expense_tags WHERE group_id = ?', [gid]);
        await tx.execute('DELETE FROM group_invites WHERE group_id = ?', [gid]);
      }
      await tx.execute('DELETE FROM invite_usages');
      await tx.execute('DELETE FROM groups');

      for (final g in groups) {
        final isPersonal = (g['is_personal'] ?? false) == true;
        final budgetCents = (g['budget_amount_cents'] as num?)?.toInt();
        await tx.execute(
          '''INSERT INTO groups (id, name, currency_code, owner_id, settlement_method,
            treasurer_participant_id, settlement_freeze_at, settlement_snapshot_json,
            allow_member_add_expense, allow_member_add_participant, allow_member_change_settings,
            require_participant_assignment, allow_expense_as_other_participant, icon, color, archived_at, is_personal, budget_amount_cents, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
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
            g['allow_member_add_participant'] == true ? 1 : 0,
            g['allow_member_change_settings'] == true ? 1 : 0,
            g['require_participant_assignment'] == true ? 1 : 0,
            (g['allow_expense_as_other_participant'] ?? true) == true ? 1 : 0,
            g['icon'],
            g['color'],
            g['archived_at'],
            isPersonal ? 1 : 0,
            budgetCents,
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
          'INSERT INTO participants (id, group_id, name, sort_order, user_id, avatar_id, left_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            p['id'],
            p['group_id'],
            p['name'],
            p['sort_order'],
            p['user_id'],
            p['avatar_id'],
            p['left_at'],
            p['created_at'],
            p['updated_at'],
          ],
        );
      }
      for (final e in expenses) {
        await tx.execute(
          '''INSERT INTO expenses (id, group_id, payer_participant_id, amount_cents,
            currency_code, exchange_rate, base_amount_cents, title, description, date,
            split_type, split_shares_json, type, to_participant_id, tag, line_items_json,
            receipt_image_path, receipt_image_paths, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            e['id'],
            e['group_id'],
            e['payer_participant_id'],
            e['amount_cents'],
            e['currency_code'],
            e['exchange_rate'],
            e['base_amount_cents'],
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
            e['receipt_image_paths'],
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
            usage['id'] as String,
            usage['invite_id'],
            usage['user_id'],
            usage['accepted_at'],
          ],
        );
      }
    });
  }
}
