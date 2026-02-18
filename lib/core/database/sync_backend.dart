import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract backend for sync operations. Used by [SyncEngine] for testing;
/// production uses [SupabaseSyncBackend].
abstract class SyncBackend {
  String? get currentUserId;

  Future<List<Map<String, dynamic>>> getGroupIdsForUser(String userId);
  Future<List<Map<String, dynamic>>> getGroups(List<String> groupIds);
  Future<List<Map<String, dynamic>>> getMembers(List<String> groupIds);
  Future<List<Map<String, dynamic>>> getParticipants(List<String> groupIds);
  Future<List<Map<String, dynamic>>> getExpenses(List<String> groupIds);
  Future<List<Map<String, dynamic>>> getTags(List<String> groupIds);
  Future<List<Map<String, dynamic>>> getInvites(List<String> groupIds);
  Future<List<Map<String, dynamic>>> getInviteUsages(List<String> inviteIds);

  Future<void> upsert(String table, Map<String, dynamic> data);
  Future<void> update(String table, Map<String, dynamic> data, String id);
  Future<void> delete(String table, String id);
}

/// Production implementation using [SupabaseClient].
class SupabaseSyncBackend implements SyncBackend {
  SupabaseSyncBackend(this._client);
  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<List<Map<String, dynamic>>> getGroupIdsForUser(String userId) async {
    final rows = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> getGroups(List<String> groupIds) async {
    if (groupIds.isEmpty) return [];
    final rows = await _client.from('groups').select().inFilter('id', groupIds);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> getMembers(List<String> groupIds) async {
    if (groupIds.isEmpty) return [];
    final rows = await _client
        .from('group_members')
        .select()
        .inFilter('group_id', groupIds);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> getParticipants(List<String> groupIds) async {
    if (groupIds.isEmpty) return [];
    final rows = await _client
        .from('participants')
        .select()
        .inFilter('group_id', groupIds);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> getExpenses(List<String> groupIds) async {
    if (groupIds.isEmpty) return [];
    final rows = await _client
        .from('expenses')
        .select()
        .inFilter('group_id', groupIds);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> getTags(List<String> groupIds) async {
    if (groupIds.isEmpty) return [];
    final rows = await _client
        .from('expense_tags')
        .select()
        .inFilter('group_id', groupIds);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> getInvites(List<String> groupIds) async {
    if (groupIds.isEmpty) return [];
    final rows = await _client
        .from('group_invites')
        .select()
        .inFilter('group_id', groupIds);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> getInviteUsages(List<String> inviteIds) async {
    if (inviteIds.isEmpty) return [];
    try {
      final rows = await _client
          .from('invite_usages')
          .select()
          .inFilter('invite_id', inviteIds);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    await _client.from(table).upsert(data);
  }

  @override
  Future<void> update(String table, Map<String, dynamic> data, String id) async {
    await _client.from(table).update(data).eq('id', id);
  }

  @override
  Future<void> delete(String table, String id) async {
    await _client.from(table).delete().eq('id', id);
  }
}
