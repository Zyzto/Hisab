import 'package:flutter_test/flutter_test.dart';

import 'package:hisab/core/update/app_update_helper.dart';

void main() {
  test('staging update source opens the Hisab GitHub entry in Obtainium', () {
    expect(testUpdateSourceUri.scheme, 'obtainium');
    expect(testUpdateSourceUri.host, 'add');
    expect(
      testUpdateSourceUri.queryParameters['url'],
      'https://github.com/Zyzto/Hisab',
    );
  });
}
