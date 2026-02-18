import 'package:flutter_test/flutter_test.dart';

import 'package:hisab/app.dart';

/// Minimal sanity test that the app module loads. Full UI is covered by
/// the balance widget test and manual runs.
void main() {
  test('App widget can be instantiated', () {
    expect(const App(), isNotNull);
  });
}
