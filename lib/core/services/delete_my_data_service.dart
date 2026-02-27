import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_config.dart';
import '../../domain/delete_my_data_preview.dart';

part 'delete_my_data_service.g.dart';

/// Service for Delete cloud data: preview and execute deletion on Supabase.
@Riverpod(keepAlive: true)
DeleteMyDataService deleteMyDataService(Ref ref) => DeleteMyDataService();

class DeleteMyDataService {
  SupabaseClient? get _client => supabaseClientIfConfigured;

  /// Fetches counts for the current user (groups where owner, memberships, device tokens, invite usages, sole-member groups).
  Future<DeleteMyDataPreview> getDeleteMyDataPreview() async {
    final client = _client;
    if (client == null) {
      throw UnsupportedError('getDeleteMyDataPreview requires Supabase');
    }
    final res = await client.rpc('get_delete_my_data_preview');
    if (res == null) {
      return const DeleteMyDataPreview(
        groupsWhereOwner: 0,
        groupMemberships: 0,
        deviceTokensCount: 0,
        inviteUsagesCount: 0,
        soleMemberGroupCount: 0,
      );
    }
    final map = res is Map ? Map<String, dynamic>.from(Map.from(res)) : null;
    if (map == null) {
      return const DeleteMyDataPreview(
        groupsWhereOwner: 0,
        groupMemberships: 0,
        deviceTokensCount: 0,
        inviteUsagesCount: 0,
        soleMemberGroupCount: 0,
      );
    }
    Log.info('Delete my data preview: $map');
    return DeleteMyDataPreview.fromJson(map);
  }

  /// Leaves all groups (transferring ownership where applicable), then deletes device_tokens and invite_usages for the current user.
  Future<void> deleteMyData() async {
    final client = _client;
    if (client == null) {
      throw UnsupportedError('deleteMyData requires Supabase');
    }
    await client.rpc('delete_my_data');
    Log.info('Delete my data (cloud) completed');
  }
}
