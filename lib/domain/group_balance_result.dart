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

  const GroupBalanceResult({
    required this.group,
    required this.participants,
    required this.balances,
    required this.settlements,
  });
}
