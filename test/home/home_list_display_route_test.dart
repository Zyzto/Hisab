import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/home/routes.dart';

void main() {
  test('homeListDisplayFromMode maps path segments', () {
    expect(homeListDisplayFromMode('separate'), 'list_separate');
    expect(homeListDisplayFromMode('combined'), 'list_combined');
    expect(homeListDisplayFromMode('other'), isNull);
  });

  test('homeListDisplayFromPath maps /home/:mode URLs', () {
    expect(homeListDisplayFromPath('/home/separate'), 'list_separate');
    expect(homeListDisplayFromPath('/home/combined'), 'list_combined');
    expect(homeListDisplayFromPath('/'), isNull);
    expect(homeListDisplayFromPath('/settings'), isNull);
    expect(homeListDisplayFromPath('/home/nope'), isNull);
  });
}
