import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/settings/backup_helper.dart';

void main() {
  group('parseBackupJson', () {
    test('returns error for invalid JSON', () {
      final result = parseBackupJson('not json');
      expect(result.data, isNull);
      expect(result.errorMessageKey, 'backup_parse_invalid_format');
    });

    test('returns error for unsupported version', () {
      final result = parseBackupJson('{"version": 2, "groups": []}');
      expect(result.data, isNull);
      expect(result.errorMessageKey, 'backup_parse_unsupported_version');
    });

    test('returns error when version is missing', () {
      final result = parseBackupJson('{"groups": [], "participants": []}');
      expect(result.data, isNull);
      expect(result.errorMessageKey, 'backup_parse_unsupported_version');
    });

    test('returns data for valid backup', () {
      const json = '''
      {
        "version": 1,
        "groups": [
          {"id": "g1", "name": "G", "currencyCode": "USD", "createdAt": "2025-01-01T00:00:00Z", "updatedAt": "2025-01-01T00:00:00Z"}
        ],
        "participants": [],
        "expenses": [],
        "expense_tags": [],
        "localArchivedGroupIds": []
      }
      ''';
      final result = parseBackupJson(json);
      expect(result.errorMessageKey, isNull);
      expect(result.data, isNotNull);
      expect(result.data!.groups.length, 1);
      expect(result.data!.groups.first.name, 'G');
      expect(result.data!.participants, isEmpty);
      expect(result.data!.expenses, isEmpty);
    });
  });
}
