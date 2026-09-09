import '../../domain/domain.dart';

abstract class IHouseholdBalanceReassignmentRepository {
  Future<List<HouseholdBalanceReassignment>> getByGroupId(String groupId);

  Stream<List<HouseholdBalanceReassignment>> watchByGroupId(String groupId);

  Future<void> create({
    required String groupId,
    required String sourceParticipantId,
    required String targetParticipantId,
    required int amountCents,
  });
}
