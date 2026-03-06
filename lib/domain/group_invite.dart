enum InviteAccessMode {
  standard('standard'),
  readonlyJoin('readonly_join'),
  readonlyOnly('readonly_only');

  const InviteAccessMode(this.value);
  final String value;

  static InviteAccessMode fromValue(String? value) {
    switch (value) {
      case 'readonly_join':
        return InviteAccessMode.readonlyJoin;
      case 'readonly_only':
        return InviteAccessMode.readonlyOnly;
      case 'standard':
      default:
        return InviteAccessMode.standard;
    }
  }
}

/// Domain entity: a pending invite to join a group.
class GroupInvite {
  final String id;
  final String groupId;
  final String token;
  final String? inviteeEmail;
  final String role;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? createdBy;
  final String? label;
  final int? maxUses;
  final int useCount;
  final bool isActive;
  final InviteAccessMode accessMode;

  const GroupInvite({
    required this.id,
    required this.groupId,
    required this.token,
    this.inviteeEmail,
    required this.role,
    required this.createdAt,
    this.expiresAt,
    this.createdBy,
    this.label,
    this.maxUses,
    this.useCount = 0,
    this.isActive = true,
    this.accessMode = InviteAccessMode.standard,
  });

  /// Whether the invite has passed its expiry date.
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Whether the invite has reached its max usage limit.
  bool get isMaxedOut => maxUses != null && useCount >= maxUses!;

  /// Whether the invite can currently be used to join.
  bool get isUsable => isActive && !isExpired && !isMaxedOut;

  /// A status category for display purposes.
  InviteStatus get status {
    if (!isActive) return InviteStatus.revoked;
    if (isExpired) return InviteStatus.expired;
    if (isMaxedOut) return InviteStatus.maxedOut;
    return InviteStatus.active;
  }

  GroupInvite copyWith({
    String? id,
    String? groupId,
    String? token,
    String? inviteeEmail,
    String? role,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? createdBy,
    String? label,
    int? maxUses,
    int? useCount,
    bool? isActive,
    InviteAccessMode? accessMode,
  }) {
    return GroupInvite(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      token: token ?? this.token,
      inviteeEmail: inviteeEmail ?? this.inviteeEmail,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdBy: createdBy ?? this.createdBy,
      label: label ?? this.label,
      maxUses: maxUses ?? this.maxUses,
      useCount: useCount ?? this.useCount,
      isActive: isActive ?? this.isActive,
      accessMode: accessMode ?? this.accessMode,
    );
  }
}

/// Enumeration of invite statuses for display.
enum InviteStatus { active, expired, maxedOut, revoked }
