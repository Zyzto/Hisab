import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/settings/initial_language.dart';

void main() {
  group('resolveInitialLanguageCode', () {
    test('uses supported platform language', () {
      expect(resolveInitialLanguageCode(platformLanguageCode: 'ar'), 'ar');
      expect(resolveInitialLanguageCode(platformLanguageCode: 'en'), 'en');
    });

    test('normalizes case', () {
      expect(resolveInitialLanguageCode(platformLanguageCode: 'AR'), 'ar');
    });

    test('falls back for unsupported or null platform language', () {
      expect(resolveInitialLanguageCode(platformLanguageCode: 'fr'), 'en');
      expect(resolveInitialLanguageCode(platformLanguageCode: null), 'en');
    });
  });
}
