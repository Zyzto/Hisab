/// Settlement calculation method for a group.
enum SettlementMethod {
  /// Relationship-based: per-pair net, minimizes transactions between same two people.
  pairwise,

  /// Global minimization: fewest transfers overall.
  greedy,

  /// Itemized per payer: one transfer per creditor with expense breakdown.
  consolidated,

  /// Centralized: everyone pays/receives through one treasurer.
  treasurer,
}
