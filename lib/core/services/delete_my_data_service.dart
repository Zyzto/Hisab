import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:hisab_backend/hisab_backend.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/delete_my_data_preview.dart';

part 'delete_my_data_service.g.dart';

/// Preview and execute erasure of the user's cloud footprint.
@Riverpod(keepAlive: true)
DeleteMyDataService deleteMyDataService(Ref ref) => DeleteMyDataService();

class DeleteMyDataService {
  CloudAccount get _accountOrThrow =>
      cloudBackend?.account ??
      (throw UnsupportedError('Delete my data requires a cloud backend'));

  static const _empty = DeleteMyDataPreview(
    groupsWhereOwner: 0,
    groupMemberships: 0,
    deviceTokensCount: 0,
    inviteUsagesCount: 0,
    soleMemberGroupCount: 0,
  );

  /// Counts of what deletion would affect, so the confirmation screen can state
  /// the consequences before the user commits.
  Future<DeleteMyDataPreview> getDeleteMyDataPreview() async {
    final map = await _accountOrThrow.deleteMyDataPreview();
    if (map == null) return _empty;
    Log.info('Delete my data preview: $map');
    return DeleteMyDataPreview.fromJson(map);
  }

  /// Leaves all groups (transferring ownership where applicable), then deletes
  /// device tokens and invite usages for the current user.
  Future<void> deleteMyData() async {
    await _accountOrThrow.deleteMyData();
    Log.info('Delete my data (cloud) completed');
  }
}
