import '../../domain/domain.dart';

abstract class IGroupRepository {
  Future<List<Group>> getAll();
  Stream<List<Group>> watchAll();
  Stream<List<Group>> watchArchived();
  Future<Group?> getById(String id);

  /// Live updates for a single group (native SQLite watch / web poll).
  Stream<Group?> watchById(String id);
  Future<String> create(
    String name,
    String currencyCode, {
    String? icon,
    int? color,
    List<String> initialParticipants = const [],
    bool isPersonal = false,
    int? budgetAmountCents,
    SettlementMethod settlementMethod = SettlementMethod.greedy,
    bool allowMemberAddExpense = true,
    bool allowMemberChangeSettings = true,
    bool allowExpenseAsOtherParticipant = true,
    bool allowMemberSettleForOthers = false,
  });
  Future<void> update(Group group);
  Future<void> delete(String id);
  Future<void> freezeSettlement(String groupId, SettlementSnapshot snapshot);
  Future<void> unfreezeSettlement(String groupId);
  Future<void> archive(String groupId);
  Future<void> unarchive(String groupId);

  /// Local-only: hide group from current user's list (non-owners). Not synced.
  Future<void> setLocalArchived(String groupId);
  Future<void> clearLocalArchived(String groupId);
  Future<Set<String>> getLocallyArchivedGroupIds();
  Stream<Set<String>> watchLocallyArchivedGroupIds();
  Stream<List<Group>> watchLocallyArchivedGroups();
}
