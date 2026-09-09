/// Balance for one participant in a group (computed from expenses).
/// Positive = others owe them; negative = they owe others.
/// [balanceCents] is in smallest currency unit.
class ParticipantBalance {
  final String participantId;
  final int balanceCents;
  final String currencyCode;

  const ParticipantBalance({
    required this.participantId,
    required this.balanceCents,
    required this.currencyCode,
  });

  ParticipantBalance copyWith({
    String? participantId,
    int? balanceCents,
    String? currencyCode,
  }) => ParticipantBalance(
    participantId: participantId ?? this.participantId,
    balanceCents: balanceCents ?? this.balanceCents,
    currencyCode: currencyCode ?? this.currencyCode,
  );
}
