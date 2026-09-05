import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/constants/confirmation_durations.dart';

void main() {
  test('destructive confirmations wait ten seconds', () {
    expect(destructiveConfirmationSeconds, 10);
  });
}
