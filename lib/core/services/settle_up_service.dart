import '../../domain/domain.dart';

/// Greedy debt minimization: compute the fewest transfers to settle balances.
/// [balances] is a list of (participantId, balanceCents). Positive = owed to them.
/// Returns list of (fromId, toId, amountCents).
List<SettlementTransaction> computeSettleUp(
  List<ParticipantBalance> balances,
  String currencyCode,
) {
  final debtors = <String, int>{}; // negative balance -> amount to pay
  final creditors = <String, int>{}; // positive balance -> amount to receive

  for (final b in balances) {
    if (b.balanceCents > 0) {
      creditors[b.participantId] = b.balanceCents;
    } else if (b.balanceCents < 0) {
      debtors[b.participantId] = -b.balanceCents;
    }
  }

  final result = <SettlementTransaction>[];

  for (final entry in debtors.entries) {
    int remaining = entry.value;
    final fromId = entry.key;

    for (final cred in creditors.entries) {
      if (remaining <= 0) break;
      final toId = cred.key;
      final credit = cred.value;
      if (credit <= 0) continue;

      final transfer = remaining < credit ? remaining : credit;
      result.add(
        SettlementTransaction(
          fromParticipantId: fromId,
          toParticipantId: toId,
          amountCents: transfer,
          currencyCode: currencyCode,
        ),
      );
      remaining -= transfer;
      creditors[toId] = credit - transfer;
    }
  }

  return result;
}

/// Compute per-participant balances from expenses and participants.
/// Balance = what they paid minus what they owe. Positive = owed to them.
List<ParticipantBalance> computeBalances(
  List<Participant> participants,
  List<Expense> expenses,
  String currencyCode,
) {
  final paid = <String, int>{};
  final owed = <String, int>{};

  for (final p in participants) {
    paid[p.id] = 0;
    owed[p.id] = 0;
  }

  for (final e in expenses) {
    paid[e.payerParticipantId] =
        (paid[e.payerParticipantId] ?? 0) + e.amountCents;

    final shares = _computeShares(e);
    for (final entry in shares.entries) {
      owed[entry.key] = (owed[entry.key] ?? 0) + entry.value;
    }
  }

  return participants.map((p) {
    final pPaid = paid[p.id] ?? 0;
    final pOwed = owed[p.id] ?? 0;
    return ParticipantBalance(
      participantId: p.id,
      balanceCents: pPaid - pOwed,
      currencyCode: currencyCode,
    );
  }).toList();
}

/// For an expense, compute how much each participant owes (in cents).
Map<String, int> _computeShares(Expense e) {
  switch (e.splitType) {
    case SplitType.equal:
      if (e.splitShares.isEmpty) return {};
      return Map.from(e.splitShares);
    case SplitType.parts:
    case SplitType.amounts:
      return Map.from(e.splitShares);
  }
}
