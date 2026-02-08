/// Result of the settle-up algorithm: one transfer from debtor to creditor.
/// [amountCents] is in smallest currency unit.
class SettlementTransaction {
  final String fromParticipantId;
  final String toParticipantId;
  final int amountCents;
  final String currencyCode;

  const SettlementTransaction({
    required this.fromParticipantId,
    required this.toParticipantId,
    required this.amountCents,
    required this.currencyCode,
  });
}
