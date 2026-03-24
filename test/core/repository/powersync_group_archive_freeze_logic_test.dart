import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/repository/powersync_repository.dart';

void main() {
  test('archive auto-freezes only when group was not frozen', () {
    expect(shouldAutoFreezeOnArchive(null), isTrue);
    expect(shouldAutoFreezeOnArchive(''), isTrue);
    expect(shouldAutoFreezeOnArchive('2026-03-23T10:00:00.000Z'), isFalse);
  });

  test('unarchive auto-unfreezes only for archive auto-freeze marker', () {
    expect(
      shouldAutoUnfreezeOnUnarchive(archiveAutoFreezeSnapshotMarker),
      isTrue,
    );
    expect(shouldAutoUnfreezeOnUnarchive(null), isFalse);
    expect(shouldAutoUnfreezeOnUnarchive(''), isFalse);
    expect(
      shouldAutoUnfreezeOnUnarchive('{"frozenAt":1,"balances":[],"settlements":[]}'),
      isFalse,
    );
  });
}
