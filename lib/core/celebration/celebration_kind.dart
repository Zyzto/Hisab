/// One-shot biome celebrations (forest / jungle / sea / plants / sky).
enum CelebrationKind {
  /// First non-transfer expense in a group.
  firstExpense,

  /// A new expense (not a settlement transfer).
  newExpense,

  /// Settlement / transfer recorded.
  settlement,

  /// A person became an active participant.
  personJoined,

  /// A person left / was kicked / archived.
  personLeft,

  /// A shared group was created.
  newGroup,

  /// A personal list was created.
  newPersonalList,
}

class CelebrationRequest {
  CelebrationRequest(this.kind, {this.dedupeKey, DateTime? at})
    : at = at ?? DateTime.now();

  final CelebrationKind kind;
  final String? dedupeKey;
  final DateTime at;
}

/// Stable dedupe keys so join/leave fire once per person per group.
abstract final class CelebrationKeys {
  static String personJoined(String groupId, String participantId) =>
      'join:$groupId:$participantId';

  static String personLeft(String groupId, String participantId) =>
      'leave:$groupId:$participantId';

  static String groupCreated(String groupId) => 'create:$groupId';
}
