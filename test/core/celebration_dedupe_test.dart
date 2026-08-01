import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/celebration/celebration_dedupe.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CelebrationDedupe.instance.debugReset();
  });

  test('tryClaim allows a key only once', () async {
    final dedupe = CelebrationDedupe.instance;
    expect(await dedupe.tryClaim('join:g1:p1'), isTrue);
    expect(await dedupe.tryClaim('join:g1:p1'), isFalse);
    expect(await dedupe.tryClaim('leave:g1:p1'), isTrue);
  });

  test('seed prevents later celebration for same key', () async {
    final dedupe = CelebrationDedupe.instance;
    await dedupe.seed(['join:g1:p2']);
    expect(await dedupe.tryClaim('join:g1:p2'), isFalse);
    expect(await dedupe.tryClaim('join:g1:p3'), isTrue);
  });
}
