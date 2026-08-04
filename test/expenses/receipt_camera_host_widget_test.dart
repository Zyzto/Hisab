import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/motion/app_motion.dart';
import 'package:hisab/features/expenses/camera/receipt_camera_types.dart';

/// Mirrors the host height math from show_receipt_camera_io for a focused test.
class _HeightToggleHost extends StatefulWidget {
  const _HeightToggleHost();

  @override
  State<_HeightToggleHost> createState() => _HeightToggleHostState();
}

class _HeightToggleHostState extends State<_HeightToggleHost> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final panelH = expanded ? h : h * kReceiptCameraCompactHeightFraction;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.modal;
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        key: const ValueKey('panel'),
        duration: duration,
        curve: AppMotion.enterCurve,
        height: panelH,
        width: 400,
        color: Colors.black,
        child: IconButton(
          key: const ValueKey('toggle'),
          onPressed: () => setState(() => expanded = !expanded),
          icon: Icon(expanded ? Icons.close_fullscreen : Icons.open_in_full),
        ),
      ),
    );
  }
}

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
      const MaterialApp(home: Scaffold(body: _HeightToggleHost())),
    );
    await tester.pumpAndSettle();

    final compactBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('panel')),
    );
    expect(compactBox.size.height, closeTo(screenH * 0.65, 0.5));

    await tester.tap(find.byKey(const ValueKey('toggle')));
    await tester.pump();
    await tester.pump(AppMotion.modal);
    await tester.pumpAndSettle();

    final fullBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('panel')),
    );
    expect(fullBox.size.height, closeTo(screenH, 0.5));

    await tester.tap(find.byKey(const ValueKey('toggle')));
    await tester.pump();
    await tester.pump(AppMotion.modal);
    await tester.pumpAndSettle();

    final backBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('panel')),
    );
    expect(backBox.size.height, closeTo(screenH * 0.65, 0.5));
  });
}
