class RoutePaths {
  static const String home = '/';
  static const String settings = '/settings';
  static const String onboarding = '/onboarding';

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
  static String groupEdit(String groupId) => '/groups/$groupId/edit';
  static String groupSettings(String groupId) => '/groups/$groupId/settings';

  static String inviteAccept(String token) => '/invite/$token';

  static String? extractGroupId(String path) {
    final match = RegExp(r'/groups/([^/]+)').firstMatch(path);
    return match?.group(1);
  }

  static String? extractExpenseId(String path) {
    final match = RegExp(r'/expenses/([^/]+)').firstMatch(path);
    return match?.group(1);
  }

  static String? extractInviteToken(String path) {
    final match = RegExp(r'/invite/([^/]+)').firstMatch(path);
    return match?.group(1);
  }
}
