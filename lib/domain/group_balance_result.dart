import 'group.dart';
import 'participant.dart';
import 'participant_balance.dart';
import 'settlement_transaction.dart';

/// Result of balance computation for a group. Used by [groupBalanceProvider].
class GroupBalanceResult {
  final Group group;
  final List<Participant> participants;
  final List<ParticipantBalance> balances;
  final List<SettlementTransaction> settlements;

  /// True when the group is frozen but [Group.settlementSnapshotJson] could not
  /// be parsed. Balances/settlements are empty; UI should warn rather than show
  /// live recomputed numbers.
  final bool snapshotCorrupt;

  const GroupBalanceResult({
    required this.group,
    required this.participants,
    required this.balances,
    required this.settlements,
    this.snapshotCorrupt = false,
  });
}
