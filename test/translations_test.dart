import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> en;
  late Map<String, dynamic> ar;

  setUpAll(() async {
    final enString = await rootBundle.loadString('assets/translations/en.json');
    final arString = await rootBundle.loadString('assets/translations/ar.json');
    en = jsonDecode(enString) as Map<String, dynamic>;
    ar = jsonDecode(arString) as Map<String, dynamic>;
  });

  group('Translation files', () {
    test('en.json and ar.json are valid JSON with string values', () {
      expect(en, isA<Map<String, dynamic>>());
      expect(ar, isA<Map<String, dynamic>>());
      for (final entry in en.entries) {
        expect(entry.value, isA<String>(), reason: 'en["${entry.key}"]');
      }
      for (final entry in ar.entries) {
        expect(entry.value, isA<String>(), reason: 'ar["${entry.key}"]');
      }
    });

    test('both locales have the same set of keys', () {
      final enKeys = en.keys.toSet();
      final arKeys = ar.keys.toSet();
      final missingInAr = enKeys.difference(arKeys);
      final missingInEn = arKeys.difference(enKeys);
      expect(missingInAr, isEmpty, reason: 'Keys in en but not in ar: $missingInAr');
      expect(missingInEn, isEmpty, reason: 'Keys in ar but not in en: $missingInEn');
    });

    test('critical UI keys exist and are non-empty in en', () {
      const critical = [
        'app_name',
        'groups',
        'settings',
        'balance',
        'settle_up',
        'expenses',
        'participants',
        'create_group',
        'add_expense',
        'cancel',
        'submit',
        'record_settlement',
        'all_settled',
        'settlement_frozen',
        'settlement_frozen_hint',
        'unfreeze_settlement',
      ];
      for (final key in critical) {
        expect(en.containsKey(key), true, reason: 'Missing key: $key');
        final value = en[key] as String?;
        expect(value, isNotNull, reason: 'Null value for: $key');
        expect(value!.trim().isNotEmpty, true, reason: 'Empty value for: $key');
      }
    });

    test('critical UI keys exist and are non-empty in ar', () {
      const critical = [
        'app_name',
        'groups',
        'settings',
        'balance',
        'settle_up',
        'expenses',
        'participants',
        'create_group',
        'add_expense',
        'cancel',
        'submit',
        'record_settlement',
        'all_settled',
        'settlement_frozen',
        'settlement_frozen_hint',
        'unfreeze_settlement',
      ];
      for (final key in critical) {
        expect(ar.containsKey(key), true, reason: 'Missing key: $key');
        final value = ar[key] as String?;
        expect(value, isNotNull, reason: 'Null value for: $key');
        expect(value!.trim().isNotEmpty, true, reason: 'Empty value for: $key');
      }
    });
  });
}
