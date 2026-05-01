/// A whitelist entry for a notification sender.
class SenderRule {
  final String id;
  final String packageName;
  final String? senderLabel;
  final String? senderNumber;
  final bool enabled;
  final int matchCount;
  final DateTime createdAt;

  const SenderRule({
    required this.id,
    required this.packageName,
    this.senderLabel,
    this.senderNumber,
    this.enabled = true,
    this.matchCount = 0,
    required this.createdAt,
  });

  SenderRule copyWith({
    String? id,
    String? packageName,
    String? senderLabel,
    String? senderNumber,
    bool? enabled,
    int? matchCount,
    DateTime? createdAt,
  }) {
    return SenderRule(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      senderLabel: senderLabel ?? this.senderLabel,
      senderNumber: senderNumber ?? this.senderNumber,
      enabled: enabled ?? this.enabled,
      matchCount: matchCount ?? this.matchCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Display name: user label, or cleaned-up package name.
  String get displayName {
    if (senderLabel != null && senderLabel!.isNotEmpty) return senderLabel!;
    final parts = packageName.split('.');
    return parts.length > 1 ? parts.last : packageName;
  }
}
