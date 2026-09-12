/// Legacy role values retained for displaying older local records.
enum GroupRole {
  owner,
  admin,
  member;

  static GroupRole? fromString(String? value) {
    switch (value) {
      case 'owner':
        return GroupRole.owner;
      case 'admin':
        return GroupRole.admin;
      case 'member':
        return GroupRole.member;
      default:
        return null;
    }
  }
}
