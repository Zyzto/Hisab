/// Role of a user in a group.
enum GroupRole {
  owner,
  admin,
  member;

  static GroupRole? fromString(String? s) {
    if (s == null) return null;
    switch (s) {
      case 'owner':
        return GroupRole.owner;
      case 'admin':
        return GroupRole.admin;
      case 'member':
        return GroupRole.member;
      default:
        return GroupRole.member;
    }
  }
}
