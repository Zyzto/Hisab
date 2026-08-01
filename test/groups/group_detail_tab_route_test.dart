import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/navigation/route_paths.dart';
import 'package:hisab/features/groups/pages/group_create_page.dart';
import 'package:hisab/features/groups/pages/group_detail_page.dart';
import 'package:hisab/features/onboarding/pages/onboarding_page.dart';

void main() {
  group('Group detail tab route paths', () {
    test('builds explicit tab paths from group id', () {
      expect(RoutePaths.groupExpenses('g1'), '/groups/g1/expenses');
      expect(RoutePaths.groupBalance('g1'), '/groups/g1/balance');
      expect(RoutePaths.groupPeople('g1'), '/groups/g1/people');
    });

    test('groupDetail is canonical expenses tab URL', () {
      expect(RoutePaths.groupDetail('g1'), '/groups/g1/expenses');
      expect(RoutePaths.groupDetail('g1'), RoutePaths.groupExpenses('g1'));
    });

    test('maps location path to tab index for reload sync', () {
      expect(
        groupDetailTabIndexFromPath(path: '/groups/g1/expenses', groupId: 'g1'),
        0,
      );
      expect(
        groupDetailTabIndexFromPath(path: '/groups/g1/balance', groupId: 'g1'),
        1,
      );
      expect(
        groupDetailTabIndexFromPath(path: '/groups/g1/people', groupId: 'g1'),
        2,
      );
      expect(
        groupDetailTabIndexFromPath(path: '/groups/other/balance', groupId: 'g1'),
        isNull,
      );
      expect(
        groupDetailTabIndexFromPath(
          path: '/invite/tok/preview/balance',
          groupId: 'g1',
          readOnlyPreview: true,
          previewToken: 'tok',
        ),
        1,
      );
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

    test('maps create-wizard path to step index for reload sync', () {
      expect(
        groupCreateStepFromPath('/groups/create/style', isPersonal: false),
        2,
      );
      expect(
        groupCreateStepFromPath(
          '/groups/create-personal/review',
          isPersonal: true,
        ),
        2,
      );
      expect(
        groupCreateStepFromPath('/groups/create/style', isPersonal: true),
        isNull,
      );
    });

    test('maps onboarding path to step index for reload sync', () {
      expect(onboardingStepFromPath('/onboarding/welcome'), 0);
      expect(onboardingStepFromPath('/onboarding/preferences'), 1);
      expect(onboardingStepFromPath('/onboarding/permissions'), 2);
      expect(onboardingStepFromPath('/onboarding/connect'), 3);
      expect(onboardingStepFromPath('/home'), isNull);
    });

    test('builds home mode path', () {
      expect(RoutePaths.homeMode('combined'), '/home/combined');
      expect(RoutePaths.homeMode('separate'), '/home/separate');
    });
  });
}
