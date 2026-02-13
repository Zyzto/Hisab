/// Domain entity: a record of a user accepting a group invite.
class InviteUsage {
  final String id;
  final String inviteId;
  final String userId;
  final DateTime acceptedAt;

  const InviteUsage({
    required this.id,
    required this.inviteId,
    required this.userId,
    required this.acceptedAt,
  });
}
