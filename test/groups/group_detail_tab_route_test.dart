import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/navigation/route_paths.dart';

void main() {
  group('Group detail tab route paths', () {
    test('builds explicit tab paths from group id', () {
      expect(RoutePaths.groupExpenses('g1'), '/groups/g1/expenses');
      expect(RoutePaths.groupBalance('g1'), '/groups/g1/balance');
      expect(RoutePaths.groupPeople('g1'), '/groups/g1/people');
    });

    test('keeps legacy detail path for redirects', () {
      expect(RoutePaths.groupDetail('g1'), '/groups/g1');
    });
  });

  group('RoutePaths URL sync helpers', () {
    test('builds invite preview tab paths', () {
      expect(RoutePaths.invitePreviewExpenses('tok'), '/invite/tok/preview/expenses');
      expect(RoutePaths.invitePreviewBalance('tok'), '/invite/tok/preview/balance');
      expect(RoutePaths.invitePreviewPeople('tok'), '/invite/tok/preview/people');
    });

    test('builds onboarding step paths', () {
      expect(RoutePaths.onboardingWelcome, '/onboarding/welcome');
      expect(RoutePaths.onboardingPreferences, '/onboarding/preferences');
      expect(RoutePaths.onboardingPermissions, '/onboarding/permissions');
      expect(RoutePaths.onboardingConnect, '/onboarding/connect');
    });

    test('builds group-create step paths', () {
      expect(RoutePaths.groupCreateDetails, '/groups/create/details');
      expect(RoutePaths.groupCreateParticipants, '/groups/create/participants');
      expect(RoutePaths.groupCreateStyle, '/groups/create/style');
      expect(RoutePaths.groupCreateReview, '/groups/create/review');
      expect(
        RoutePaths.groupCreatePersonalDetails,
        '/groups/create-personal/details',
      );
      expect(RoutePaths.groupCreatePersonalStyle, '/groups/create-personal/style');
      expect(
        RoutePaths.groupCreatePersonalReview,
        '/groups/create-personal/review',
      );
    });

    test('builds home mode path', () {
      expect(RoutePaths.homeMode('combined'), '/home/combined');
      expect(RoutePaths.homeMode('separate'), '/home/separate');
    });
  });
}
