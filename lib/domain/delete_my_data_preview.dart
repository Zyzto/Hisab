/// Result of [get_delete_my_data_preview] RPC for the Delete cloud data UI.
class DeleteMyDataPreview {
  final int groupsWhereOwner;
  final int groupMemberships;
  final int deviceTokensCount;
  final int inviteUsagesCount;
  final int soleMemberGroupCount;

  const DeleteMyDataPreview({
    required this.groupsWhereOwner,
    required this.groupMemberships,
    required this.deviceTokensCount,
    required this.inviteUsagesCount,
    required this.soleMemberGroupCount,
  });

  factory DeleteMyDataPreview.fromJson(Map<String, dynamic> json) {
    return DeleteMyDataPreview(
      groupsWhereOwner: _parseInt(json['groups_where_owner']),
      groupMemberships: _parseInt(json['group_memberships']),
      deviceTokensCount: _parseInt(json['device_tokens_count']),
      inviteUsagesCount: _parseInt(json['invite_usages_count']),
      soleMemberGroupCount: _parseInt(json['sole_member_group_count']),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
