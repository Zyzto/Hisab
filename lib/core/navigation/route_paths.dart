class RoutePaths {
  static const String home = '/';
  static const String homeModeBase = '/home';
  static const String settings = '/settings';
  static const String onboarding = '/onboarding';
  static const String onboardingWelcome = '/onboarding/welcome';
  static const String onboardingPreferences = '/onboarding/preferences';
  static const String onboardingPermissions = '/onboarding/permissions';
  static const String onboardingConnect = '/onboarding/connect';
  static const String privacyPolicy = '/privacy-policy';

  static String groupDetail(String groupId) => '/groups/$groupId';
  static String groupExpenses(String groupId) => '/groups/$groupId/expenses';
  static String groupPeople(String groupId) => '/groups/$groupId/people';
  static String groupExpenseAdd(String groupId) =>
      '/groups/$groupId/expenses/add';
  static String groupExpenseDetail(String groupId, String expenseId) =>
      '/groups/$groupId/expenses/$expenseId';
  static String groupExpenseEdit(String groupId, String expenseId) =>
      '/groups/$groupId/expenses/$expenseId/edit';
  static String groupBalance(String groupId) => '/groups/$groupId/balance';
  static String groupAnalytics(String groupId) => '/groups/$groupId/analytics';
  static String groupParticipantEdit(String groupId, String participantId) =>
      '/groups/$groupId/participants/$participantId/edit';

  static const String groupCreate = '/groups/create';
  static const String groupCreatePersonal = '/groups/create-personal';
  static const String groupCreateDetails = '/groups/create/details';
  static const String groupCreateParticipants = '/groups/create/participants';
  static const String groupCreateStyle = '/groups/create/style';
  static const String groupCreateReview = '/groups/create/review';
  static const String groupCreatePersonalDetails =
      '/groups/create-personal/details';
  static const String groupCreatePersonalStyle = '/groups/create-personal/style';
  static const String groupCreatePersonalReview =
      '/groups/create-personal/review';
  static const String archivedGroups = '/archived';
  static String groupEdit(String groupId) => '/groups/$groupId/edit';
  static String groupSettings(String groupId) => '/groups/$groupId/settings';
  static String groupInvites(String groupId) => '/groups/$groupId/invites';

  static String inviteAccept(String token) => '/invite/$token';
  static String invitePreview(String token) => '/invite/$token/preview';
  static String invitePreviewExpenses(String token) => '/invite/$token/preview/expenses';
  static String invitePreviewBalance(String token) => '/invite/$token/preview/balance';
  static String invitePreviewPeople(String token) => '/invite/$token/preview/people';
  static String invitePreviewExpenseDetail(String token, String expenseId) =>
      '/invite/$token/preview/expenses/$expenseId';
  static const String scanInvite = '/scan-invite';

  static String homeMode(String mode) => '$homeModeBase/$mode';
}
