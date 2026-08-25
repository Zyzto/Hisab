import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaeh/safaeh.dart';

/// Height toggle against the shared camera sheet host.
void main() {
  testWidgets('compact ↔ full height toggle animates panel height', (
    tester,
  ) async {
    const screenH = 800.0;
    final view = tester.view;
    view.physicalSize = const Size(400, screenH);
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SafaehCameraSheetHost(
          compactHeightFraction: kSafaehCameraCompactHeightFraction,
          builder: (context, sheet) => IconButton(
            key: const ValueKey('toggle'),
            onPressed: sheet.toggleExpanded,
            icon: Icon(
              sheet.expanded ? Icons.close_fullscreen : Icons.open_in_full,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final compactBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('safaeh_camera_panel')),
    );
    expect(
      compactBox.size.height,
      closeTo(screenH * kSafaehCameraCompactHeightFraction, 0.5),
    );

    await tester.tap(find.byKey(const ValueKey('toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();

    final fullBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('safaeh_camera_panel')),
    );
    expect(fullBox.size.height, closeTo(screenH, 0.5));
  });
}
