import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/expenses/camera/receipt_camera_controller.dart';
import 'package:hisab/features/expenses/camera/receipt_camera_session.dart';
import 'package:hisab/features/expenses/camera/receipt_camera_types.dart';
import 'package:hisab/features/expenses/camera/receipt_camera_viewer.dart';
import 'package:image_picker/image_picker.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('no-camera state offers gallery escape and close', (tester) async {
    ReceiptCameraResult? popped;
    final controller = ReceiptCameraController.forTest(
      initialStatus: ReceiptCameraStatus.noCamera,
    );

    await pumpApp(
      tester,
      child: ReceiptCameraViewer(
        maxRemaining: 5,
        scanAfter: false,
        expanded: false,
        onToggleExpanded: () {},
        onPop: (r) => popped = r,
        controller: controller,
      ),
    );

    expect(find.text('receipt_camera_no_camera'.tr()), findsOneWidget);

    await tester.tap(find.text('gallery'.tr()));
    await tester.pumpAndSettle();
    expect(popped, isNotNull);
    expect(popped!.openGallery, isTrue);
    expect(popped!.images, isEmpty);

    popped = const ReceiptCameraResult(images: [], scanAfter: false);
    await pumpApp(
      tester,
      child: ReceiptCameraViewer(
        maxRemaining: 5,
        scanAfter: true,
        expanded: false,
        onToggleExpanded: () {},
        onPop: (r) => popped = r,
        controller: ReceiptCameraController.forTest(
          initialStatus: ReceiptCameraStatus.noCamera,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(popped, isNull);
  });

  testWidgets('permission denied shows settings and body copy', (tester) async {
    await pumpApp(
      tester,
      child: ReceiptCameraViewer(
        maxRemaining: 3,
        scanAfter: false,
        expanded: false,
        onToggleExpanded: () {},
        onPop: (_) {},
        controller: ReceiptCameraController.forTest(
          initialStatus: ReceiptCameraStatus.permissionDenied,
        ),
      ),
    );

    expect(find.text('receipt_camera_permission_body'.tr()), findsOneWidget);
    expect(find.text('permission_open_settings'.tr()), findsOneWidget);
    expect(find.text('gallery'.tr()), findsOneWidget);
  });

  testWidgets('close with filmstrip asks discard confirm', (tester) async {
    ReceiptCameraResult? popped = const ReceiptCameraResult(
      images: [],
      scanAfter: false,
    );
    final session = ReceiptCameraSession(maxRemaining: 5);
    session.addCapture(XFile('/tmp/a.jpg'));
    session.returnToCamera();

    await pumpApp(
      tester,
      child: ReceiptCameraViewer(
        maxRemaining: 5,
        scanAfter: false,
        expanded: false,
        onToggleExpanded: () {},
        onPop: (r) => popped = r,
        controller: ReceiptCameraController.forTest(
          initialStatus: ReceiptCameraStatus.noCamera,
        ),
        session: session,
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('receipt_camera_discard_confirm'.tr()), findsOneWidget);
    await tester.tap(find.text('cancel'.tr()));
    await tester.pumpAndSettle();
    expect(popped, isNotNull); // unchanged sentinel

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('receipt_camera_discard_action'.tr()));
    await tester.pumpAndSettle();
    expect(popped, isNull);
  });

  test('session submit shape: takeAll returns captures for ingest', () {
    final session = ReceiptCameraSession(maxRemaining: 2);
    session.addCapture(XFile('/tmp/1.jpg'));
    session.returnToCamera();
    session.addCapture(XFile('/tmp/2.jpg'));
    expect(session.atMax, isTrue);
    expect(session.canCapture, isFalse);
    final all = session.takeAll();
    expect(all, hasLength(2));
    expect(all.first.path, '/tmp/1.jpg');
  });
}
