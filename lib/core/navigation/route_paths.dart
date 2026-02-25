class RoutePaths {
  static const String home = '/';
  static const String settings = '/settings';
  static const String onboarding = '/onboarding';
  static const String privacyPolicy = '/privacy-policy';

  static String groupDetail(String groupId) => '/groups/$groupId';
  static String groupExpenses(String groupId) => '/groups/$groupId/expenses';
  static String groupExpenseAdd(String groupId) =>
      '/groups/$groupId/expenses/add';
  static String groupExpenseDetail(String groupId, String expenseId) =>
      '/groups/$groupId/expenses/$expenseId';
  static String groupExpenseEdit(String groupId, String expenseId) =>
      '/groups/$groupId/expenses/$expenseId/edit';
  static String groupBalance(String groupId) => '/groups/$groupId/balance';
  static String groupParticipantEdit(String groupId, String participantId) =>
      '/groups/$groupId/participants/$participantId/edit';

  static const String groupCreate = '/groups/create';
  static const String groupCreatePersonal = '/groups/create-personal';
  static const String archivedGroups = '/archived';
  static String groupEdit(String groupId) => '/groups/$groupId/edit';
  static String groupSettings(String groupId) => '/groups/$groupId/settings';
  static String groupInvites(String groupId) => '/groups/$groupId/invites';

  static String inviteAccept(String token) => '/invite/$token';
  static const String scanInvite = '/scan-invite';
}
