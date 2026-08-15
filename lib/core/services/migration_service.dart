import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:hisab_backend/hisab_backend.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

/// Result of a Local -> Online migration attempt.
enum MigrationResult { success, noData, failed }

/// Handles two-way data migration when switching between Local-Only and Online modes.
class MigrationService {
  final PowerSyncDatabase _db;
  final CloudBackend _cloud;

  static const _uuid = Uuid();

  MigrationService(this._db, this._cloud);

  /// Migrate all local data to the cloud when switching Local -> Online.
  ///
  /// Pushes groups (with owner_id = current user), group_members,
  /// participants, expenses, and expense_tags.
  ///
  /// [onProgress] is called with (completed, total) for UI updates.
  Future<MigrationResult> migrateLocalToOnline({
    void Function(int completed, int total)? onProgress,
  }) async {
    // Ensure the session is fresh so the backend authorizes every row of a
    // long migration, not just the first few.
    try {
      await _cloud.auth.refreshSession();
    } catch (e) {
      Log.debug('MigrationService: session refresh note: $e');
    }

    final userId = _cloud.auth.currentUser?.id;
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

      Log.info('MigrationService: migrating $total items to the cloud');

      // Push groups with owner_id = current user
      for (final g in groups) {
        final groupId = g['id'] as String;
        await _cloud.sync.upsert('groups', {
          'id': groupId,
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
          'allow_expense_as_other_participant':
              (g['allow_expense_as_other_participant'] ?? 1) == 1,
          'allow_member_settle_for_others':
              (g['allow_member_settle_for_others'] ?? 0) == 1,
          'icon': g['icon'],
          'color': g['color'],
          'archived_at': g['archived_at'],
          'is_personal': (g['is_personal'] as num?)?.toInt() == 1,
          'budget_amount_cents': g['budget_amount_cents'],
          'created_at': g['created_at'],
          'updated_at': g['updated_at'],
        });

        // Deterministic UUID so re-runs upsert the same membership row.
        final memberId = _uuid.v5(
          Namespace.url.value,
          'hisab-member:$groupId:$userId',
        );
        String? ownerParticipantId;
        for (final p in participants) {
          if (p['group_id'] != groupId) continue;
          if (p['user_id'] == userId ||
              (p['user_id'] == null &&
                  (p['sort_order'] as num?)?.toInt() == 0)) {
            ownerParticipantId = p['id'] as String?;
            break;
          }
        }

        await _cloud.sync.upsert(
          'group_members',
          {
            'id': memberId,
            'group_id': groupId,
            'user_id': userId,
            'role': 'owner',
            'participant_id': ownerParticipantId,
            'joined_at': g['created_at'],
          },
          conflictColumns: const ['group_id', 'user_id'],
        );

        completed++;
        onProgress?.call(completed, total);

        // Also update local DB with owner_id
        await _db.execute('UPDATE groups SET owner_id = ? WHERE id = ?', [
          userId,
          groupId,
        ]);
      }

      // Push participants
      for (final p in participants) {
        await _cloud.sync.upsert('participants', {
          'id': p['id'],
          'group_id': p['group_id'],
          'name': p['name'],
          'sort_order': p['sort_order'],
          'user_id': p['user_id'],
          'avatar_id': p['avatar_id'],
          'left_at': p['left_at'],
          'created_at': p['created_at'],
          'updated_at': p['updated_at'],
        });
        completed++;
        onProgress?.call(completed, total);
      }

      // Push expenses
      for (final e in expenses) {
        await _cloud.sync.upsert('expenses', {
          'id': e['id'],
          'group_id': e['group_id'],
          'payer_participant_id': e['payer_participant_id'],
          'amount_cents': e['amount_cents'],
          'currency_code': e['currency_code'],
          'exchange_rate': e['exchange_rate'],
          'base_amount_cents': e['base_amount_cents'],
          'title': e['title'],
          'description': e['description'],
          'date': e['date'],
          'split_type': e['split_type'],
          'split_shares_json': e['split_shares_json'],
          'type': e['type'],
          'to_participant_id': e['to_participant_id'],
          'tag': e['tag'],
          'line_items_json': e['line_items_json'],
          'image_path': e['image_path'],
          'image_paths': e['image_paths'],
          'created_at': e['created_at'],
          'updated_at': e['updated_at'],
        });
        completed++;
        onProgress?.call(completed, total);
      }

      // Push tags
      for (final t in tags) {
        await _cloud.sync.upsert('expense_tags', {
          'id': t['id'],
          'group_id': t['group_id'],
          'label': t['label'],
          'icon_name': t['icon_name'],
          'color': t['color'],
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

  /// Whether the local DB has any groups worth migrating.
  Future<bool> hasLocalData() async {
    final rows = await _db.getAll('SELECT COUNT(*) as cnt FROM groups');
    final count = (rows.first['cnt'] as num?)?.toInt() ?? 0;
    return count > 0;
  }
}
