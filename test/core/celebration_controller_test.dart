import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/celebration/celebration_controller.dart';
import 'package:hisab/core/celebration/celebration_kind.dart';

void main() {
  test('celebration controller plays requests sequentially after complete', () {
    final bus = CelebrationController();
    addTearDown(bus.dispose);

    bus.request(CelebrationKind.firstExpense);
    bus.request(CelebrationKind.settlement);
    bus.request(CelebrationKind.personJoined);
    expect(bus.active?.kind, CelebrationKind.firstExpense);

    bus.complete(bus.active!);
    expect(bus.active?.kind, CelebrationKind.settlement);

    bus.complete(bus.active!);
    expect(bus.active?.kind, CelebrationKind.personJoined);

    bus.complete(bus.active!);
    expect(bus.active, isNull);
  });
}
