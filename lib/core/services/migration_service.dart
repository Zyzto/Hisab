import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a Local -> Online migration attempt.
enum MigrationResult { success, noData, failed }

/// Handles two-way data migration when switching between Local-Only and Online modes.
class MigrationService {
  final PowerSyncDatabase _db;
  final SupabaseClient _client;

  MigrationService(this._db, this._client);

  /// Migrate all local data to Supabase when switching Local -> Online.
  ///
  /// Pushes groups (with owner_id = current user), group_members,
  /// participants, expenses, and expense_tags.
  ///
  /// [onProgress] is called with (completed, total) for UI updates.
  Future<MigrationResult> migrateLocalToOnline({
    void Function(int completed, int total)? onProgress,
  }) async {
    // Ensure the session is fresh so RLS sees auth.uid() (avoids 42501 after sign-in)
    try {
      await _client.auth.refreshSession();
    } catch (e) {
      Log.debug('MigrationService: session refresh note: $e');
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      Log.error('MigrationService: no authenticated user');
      return MigrationResult.failed;
    }

    try {
      // Read all local data
      final groups = await _db.getAll('SELECT * FROM groups');
      if (groups.isEmpty) {
        Log.info('MigrationService: no local data to migrate');
        return MigrationResult.noData;
      }

      final participants = await _db.getAll('SELECT * FROM participants');
      final expenses = await _db.getAll('SELECT * FROM expenses');
      final tags = await _db.getAll('SELECT * FROM expense_tags');

      final total =
          groups.length + participants.length + expenses.length + tags.length;
      var completed = 0;

      Log.info('MigrationService: migrating $total items to Supabase');

      // Push groups with owner_id = current user
      for (final g in groups) {
        await _client.from('groups').upsert({
          'id': g['id'],
          'name': g['name'],
          'currency_code': g['currency_code'],
          'owner_id': userId,
          'settlement_method': g['settlement_method'],
          'treasurer_participant_id': g['treasurer_participant_id'],
          'settlement_freeze_at': g['settlement_freeze_at'],
          'settlement_snapshot_json': g['settlement_snapshot_json'],
          'allow_member_add_expense': g['allow_member_add_expense'] == 1,
          'allow_member_change_settings':
              g['allow_member_change_settings'] == 1,
          'created_at': g['created_at'],
          'updated_at': g['updated_at'],
        });

        // Create owner membership for each group
        // Use a deterministic ID based on group + user to avoid duplicates
        final memberId = '${g['id']}_$userId'.hashCode
            .toRadixString(16)
            .padLeft(32, '0');
        try {
          await _client.from('group_members').upsert({
            'id': memberId,
            'group_id': g['id'],
            'user_id': userId,
            'role': 'owner',
            'joined_at': g['created_at'],
          });
        } catch (e) {
          // Membership might already exist if this is a retry
          Log.debug('MigrationService: membership upsert note: $e');
        }

        completed++;
        onProgress?.call(completed, total);

        // Also update local DB with owner_id
        await _db.execute('UPDATE groups SET owner_id = ? WHERE id = ?', [
          userId,
          g['id'],
        ]);
      }

      // Push participants
      for (final p in participants) {
        await _client.from('participants').upsert({
          'id': p['id'],
          'group_id': p['group_id'],
          'name': p['name'],
          'sort_order': p['sort_order'],
          'created_at': p['created_at'],
          'updated_at': p['updated_at'],
        });
        completed++;
        onProgress?.call(completed, total);
      }

      // Push expenses
      for (final e in expenses) {
        await _client.from('expenses').upsert({
          'id': e['id'],
          'group_id': e['group_id'],
          'payer_participant_id': e['payer_participant_id'],
          'amount_cents': e['amount_cents'],
          'currency_code': e['currency_code'],
          'title': e['title'],
          'description': e['description'],
          'date': e['date'],
          'split_type': e['split_type'],
          'split_shares_json': e['split_shares_json'],
          'type': e['type'],
          'to_participant_id': e['to_participant_id'],
          'tag': e['tag'],
          'line_items_json': e['line_items_json'],
          'receipt_image_path': e['receipt_image_path'],
          'created_at': e['created_at'],
          'updated_at': e['updated_at'],
        });
        completed++;
        onProgress?.call(completed, total);
      }

      // Push tags
      for (final t in tags) {
        await _client.from('expense_tags').upsert({
          'id': t['id'],
          'group_id': t['group_id'],
          'label': t['label'],
          'icon_name': t['icon_name'],
          'created_at': t['created_at'],
          'updated_at': t['updated_at'],
        });
        completed++;
        onProgress?.call(completed, total);
      }

      Log.info('MigrationService: migration complete ($completed items)');
      return MigrationResult.success;
    } catch (e, st) {
      Log.error('MigrationService: migration failed', error: e, stackTrace: st);
      return MigrationResult.failed;
    }
  }

  /// Check if there is local data that would need migration.
  Future<bool> hasLocalData() async {
    final rows = await _db.getAll('SELECT COUNT(*) as cnt FROM groups');
    final count = (rows.first['cnt'] as num?)?.toInt() ?? 0;
    return count > 0;
  }
}
