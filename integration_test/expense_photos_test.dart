// Mobile-only: uses MockPlatformInterfaceMixin (unsafe in web --release).
// Not imported by app_test.dart (CI web). Run with:
//   flutter test integration_test/expense_photos_test.dart -d <android_device>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/fake_image_picker.dart';
import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Expense photos', () {
    testWidgets('attach 4 photos from gallery', (tester) async {
      await ensureIntegrationTestReady(tester);

      await stage('enable full form', () async {
        await tapAndSettle(tester, find.text('Settings'));
        final fullFormLabel = textAnyOf(tester, [
          'Full expense form (Income & Transfer)',
          'نموذج مصروف كامل (دخل وتحويل)',
        ]);
        await scrollUntilVisible(
          tester,
          textAnyOf(tester, ['Functional', 'الوظائف']),
          maxScrolls: 80,
        );
        if (fullFormLabel.evaluate().isEmpty) {
          await tapAndSettle(
            tester,
            textAnyOf(tester, ['Functional', 'الوظائف']),
          );
          await tester.pump(const Duration(milliseconds: 300));
        }
        await scrollUntilVisible(tester, fullFormLabel, maxScrolls: 80);
        final switchFinder = find.descendant(
          of: find.ancestor(
            of: fullFormLabel,
            matching: find.byType(SwitchListTile),
          ),
          matching: find.byType(Switch),
        );
        if (switchFinder.evaluate().isNotEmpty) {
          await tapAndSettle(tester, switchFinder);
        }
        await tapAndSettle(tester, find.text('Groups'));
        await pumpAndSettleWithTimeout(tester);
      });

      await stage('create group', () async {
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await waitForWidget(tester, find.text('Create Group'));
        await tapAndSettle(tester, find.text('Create Group'));
        await pumpAndSettleWithTimeout(tester);

        await waitForWidget(
          tester,
          find.byKey(const Key('wizard_name_field')),
        );
        await enterTextAndPump(
          tester,
          find.byKey(const Key('wizard_name_field')),
          'Photo Test Group',
        );
        await waitForWidget(
          tester,
          find.byKey(const Key('wizard_next_button')),
        );
        await tapAndSettle(
          tester,
          find.byKey(const Key('wizard_next_button')),
        );
        await tester.pump(const Duration(milliseconds: 400));

        await waitForWidget(tester, find.text('Add'));
        await addWizardParticipant(tester, 'Alice');
        await addWizardParticipant(tester, 'Bob');

        await waitForWidget(
          tester,
          find.byKey(const Key('wizard_next_button')),
        );
        await tapAndSettle(
          tester,
          find.byKey(const Key('wizard_next_button')),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await waitForWidget(
          tester,
          find.byKey(const Key('wizard_next_button')),
        );
        await tapAndSettle(
          tester,
          find.byKey(const Key('wizard_next_button')),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await pumpAndSettleWithTimeout(tester);

        await tapAndPump(
          tester,
          find.byKey(const Key('wizard_create_button')),
        );
        await waitForWidget(
          tester,
          find.text('Expenses'),
          timeout: const Duration(seconds: 20),
        );
      });

      await stage('capture image and attach 4 photos', () async {
        await installFakeImagePicker();

        await waitForWidget(tester, find.byIcon(Icons.add));
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await pumpAndSettleWithTimeout(tester);

        await enterTextAndPump(
          tester,
          find.byType(TextField).first,
          'Photo Receipt',
        );
        await enterTextAndPump(tester, find.byType(TextField).at(1), '42');

        final cameraIcon = find.byIcon(Icons.camera_alt_outlined);
        expect(
          cameraIcon,
          findsWidgets,
          reason: 'Camera button should be visible on a fresh form',
        );
        await tapAndSettle(tester, cameraIcon.first);
        await pumpAndSettleWithTimeout(tester);

        expect(find.text('Camera'), findsWidgets);
        expect(find.text('Gallery'), findsWidgets);

        await tapAndSettle(tester, find.text('Gallery'));
        await pumpAndSettleWithTimeout(tester);
        await tester.pump(const Duration(seconds: 1));

        await waitForWidget(tester, find.text('Photos'));
        expect(
          find.byIcon(Icons.add_photo_alternate_outlined),
          findsOneWidget,
          reason: 'Add-more button should appear after first photo',
        );

        for (var i = 2; i <= 4; i++) {
          await scrollUntilVisible(
            tester,
            find.byIcon(Icons.add_photo_alternate_outlined),
          );
          await tapAndSettle(
            tester,
            find.byIcon(Icons.add_photo_alternate_outlined),
          );
          await pumpAndSettleWithTimeout(tester);

          final galleryOption = find.text('Gallery');
          if (galleryOption.evaluate().isNotEmpty) {
            await tapAndSettle(tester, galleryOption);
            await pumpAndSettleWithTimeout(tester);
            await tester.pump(const Duration(seconds: 1));
          }
        }

        expect(
          find.textContaining('4/5'),
          findsWidgets,
          reason: 'Should show "Photos (4/5)" after attaching 4 images',
        );
        expect(
          find.byIcon(Icons.close).evaluate().length,
          greaterThanOrEqualTo(4),
          reason: 'Should have 4 remove buttons for 4 photos',
        );

        await tapSubmitExpenseButton(tester);
        await ensureFormClosed(tester);

        await waitForWidget(tester, find.text('Photo Receipt'));
        expect(find.text('Photo Receipt'), findsWidgets);
      });

      await drainAppTimers(tester);
    });
  });
}
