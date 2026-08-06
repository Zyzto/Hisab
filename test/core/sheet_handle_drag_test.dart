import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/layout/sheet_handle_drag.dart';

void main() {
  group('SheetHandleDrag', () {
    test('pull up from compact expands on release', () {
      final drag = SheetHandleDrag();
      drag.update(-100, expanded: false);
      expect(
        drag.end(expanded: false, velocity: 0),
        SheetHandleDragAction.expand,
      );
      expect(
        drag.panelHeight(expanded: false, compactH: 650, fullH: 1000),
        750,
      );
    });

    test('pull down from compact dismisses', () {
      final drag = SheetHandleDrag();
      drag.update(120, expanded: false);
      expect(
        drag.end(expanded: false, velocity: 0),
        SheetHandleDragAction.dismiss,
      );
      expect(drag.translateY(expanded: false), 120);
    });

    test('pull down from full collapses', () {
      final drag = SheetHandleDrag();
      drag.update(100, expanded: true);
      expect(
        drag.end(expanded: true, velocity: 0),
        SheetHandleDragAction.collapse,
      );
      expect(drag.panelHeight(expanded: true, compactH: 650, fullH: 1000), 900);
    });
  });
}
