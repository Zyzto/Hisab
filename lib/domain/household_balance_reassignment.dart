/// Immutable adjustment that moves an archived participant's unresolved net
/// balance to a surviving household branch.
class HouseholdBalanceReassignment {
  final String id;
  final String groupId;
  final String sourceParticipantId;
  final String targetParticipantId;
  final int amountCents;
  final DateTime createdAt;

  const HouseholdBalanceReassignment({
    required this.id,
    required this.groupId,
    required this.sourceParticipantId,
    required this.targetParticipantId,
    required this.amountCents,
    required this.createdAt,
  });
}
