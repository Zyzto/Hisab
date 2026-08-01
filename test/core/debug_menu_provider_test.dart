import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/celebration/celebration_controller.dart';
import 'package:hisab/core/celebration/celebration_kind.dart';
import 'package:hisab/core/debug/debug_menu.dart';
import 'package:hisab/core/debug/integration_test_mode.dart';

void main() {
  tearDown(() {
    isIntegrationTestMode = false;
  });

  test('showDebugMenuProvider is true in debug builds', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(kDebugMode, isTrue);
    expect(container.read(showDebugMenuProvider), isTrue);
  });

  test('showDebugMenuProvider is false in integration test mode', () {
    isIntegrationTestMode = true;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(showDebugMenuProvider), isFalse);
  });

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
