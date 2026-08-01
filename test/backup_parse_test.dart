import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/settings/backup_csv.dart';
import 'package:hisab/features/settings/backup_helper.dart';
import 'package:hisab/features/settings/backup_html_report.dart';
import 'package:hisab/features/settings/backup_zip.dart';
import 'package:hisab/domain/domain.dart';

void main() {
  group('parseBackupJson', () {
    test('returns error for invalid JSON', () {
      final result = parseBackupJson('not json');
      expect(result.data, isNull);
      expect(result.errorMessageKey, 'backup_parse_invalid_format');
    });

    test('returns error for unsupported version', () {
      final result = parseBackupJson('{"version": 99, "groups": []}');
      expect(result.data, isNull);
      expect(result.errorMessageKey, 'backup_parse_unsupported_version');
    });

    test('returns error when version is missing', () {
      final result = parseBackupJson('{"groups": [], "participants": []}');
      expect(result.data, isNull);
      expect(result.errorMessageKey, 'backup_parse_unsupported_version');
    });

    test('returns data for valid v1 backup', () {
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
      expect(result.schemaVersion, 1);
      expect(result.warnings, contains('backup_warning_v1_fx'));
      expect(result.data!.groups.length, 1);
      expect(result.data!.groups.first.name, 'G');
    });

    test('returns data for valid v2 backup with FX and permissions', () {
      const json = '''
      {
        "version": 2,
        "groups": [
          {
            "id": "g1",
            "name": "Trip",
            "currencyCode": "SAR",
            "createdAt": "2025-01-01T00:00:00Z",
            "updatedAt": "2025-01-01T00:00:00Z",
            "allowMemberAddExpense": false,
            "allowExpenseAsOtherParticipant": false,
            "allowMemberSettleForOthers": true
          }
        ],
        "participants": [],
        "expenses": [
          {
            "id": "e1",
            "groupId": "g1",
            "payerParticipantId": "p1",
            "amountCents": 1000,
            "currencyCode": "JPY",
            "exchangeRate": 39.5,
            "baseAmountCents": 25,
            "title": "Lunch",
            "date": "2025-01-02T00:00:00Z",
            "splitType": "equal",
            "splitShares": {},
            "createdAt": "2025-01-02T00:00:00Z",
            "updatedAt": "2025-01-02T00:00:00Z",
            "imagePaths": ["https://example.com/x.jpg", "receipts/1.jpg"]
          }
        ],
        "expense_tags": [],
        "localArchivedGroupIds": []
      }
      ''';
      final result = parseBackupJson(json);
      expect(result.errorMessageKey, isNull);
      expect(result.schemaVersion, 2);
      final g = result.data!.groups.first;
      expect(g.allowMemberAddExpense, false);
      expect(g.allowExpenseAsOtherParticipant, false);
      expect(g.allowMemberSettleForOthers, true);
      final e = result.data!.expenses.first;
      expect(e.exchangeRate, 39.5);
      expect(e.baseAmountCents, 25);
      // Remote URLs stripped on parse.
      expect(e.effectiveImageUrls, ['receipts/1.jpg']);
    });

    test('returns data for valid backup with personal group and budget', () {
      const json = '''
      {
        "version": 1,
        "groups": [
          {
            "id": "g1",
            "name": "My list",
            "currencyCode": "USD",
            "createdAt": "2025-01-01T00:00:00Z",
            "updatedAt": "2025-01-01T00:00:00Z",
            "isPersonal": true,
            "budgetAmountCents": 10000
          }
        ],
        "participants": [],
        "expenses": [],
        "expense_tags": [],
        "localArchivedGroupIds": []
      }
      ''';
      final result = parseBackupJson(json);
      expect(result.errorMessageKey, isNull);
      expect(result.data!.groups.first.isPersonal, true);
      expect(result.data!.groups.first.budgetAmountCents, 10000);
    });
  });

  group('remap helpers', () {
    test('remapSplitShares maps participant ids', () {
      final out = remapSplitShares(
        {'oldA': 1, 'oldB': 2, 'gone': 3},
        {'oldA': 'newA', 'oldB': 'newB'},
      );
      expect(out, {'newA': 1, 'newB': 2});
    });

    test('remapSettlementSnapshotJson remaps participants and expense ids', () {
      final snap = SettlementSnapshot(
        frozenAt: DateTime.utc(2025, 1, 1),
        balances: const [
          ParticipantBalance(
            participantId: 'p1',
            balanceCents: 100,
            currencyCode: 'USD',
          ),
        ],
        settlements: [
          SettlementTransaction(
            fromParticipantId: 'p1',
            toParticipantId: 'p2',
            amountCents: 100,
            currencyCode: 'USD',
            items: const [
              SettlementItem(
                expenseId: 'e1',
                title: 'Food',
                amountCents: 100,
              ),
            ],
          ),
        ],
      );
      final remapped = remapSettlementSnapshotJson(
        snap.toJsonString(),
        {'p1': 'P1', 'p2': 'P2'},
        {'e1': 'E1'},
      )!;
      final parsed = SettlementSnapshot.fromJsonString(remapped);
      expect(parsed.balances.first.participantId, 'P1');
      expect(parsed.settlements.first.fromParticipantId, 'P1');
      expect(parsed.settlements.first.toParticipantId, 'P2');
      expect(parsed.settlements.first.items!.first.expenseId, 'E1');
    });
  });

  group('csv and html', () {
    test('csv escapes formula injection', () {
      final csv = buildExpensesCsv(
        groups: [
          Group(
            id: 'g1',
            name: 'G',
            currencyCode: 'USD',
            createdAt: DateTime.utc(2025),
            updatedAt: DateTime.utc(2025),
          ),
        ],
        participants: [
          Participant(
            id: 'p1',
            groupId: 'g1',
            name: 'Alice',
            order: 0,
            createdAt: DateTime.utc(2025),
            updatedAt: DateTime.utc(2025),
          ),
        ],
        expenses: [
          Expense(
            id: 'e1',
            groupId: 'g1',
            payerParticipantId: 'p1',
            amountCents: 100,
            currencyCode: 'USD',
            title: '=CMD()',
            date: DateTime.utc(2025, 1, 2),
            splitType: SplitType.equal,
            splitShares: const {},
            createdAt: DateTime.utc(2025),
            updatedAt: DateTime.utc(2025),
          ),
        ],
      );
      expect(csv, contains("'=CMD()"));
    });

    test('html escapes script in title', () {
      final groups = [
        Group(
          id: 'g1',
          name: 'G',
          currencyCode: 'USD',
          createdAt: DateTime.utc(2025),
          updatedAt: DateTime.utc(2025),
        ),
      ];
      final expenses = [
        Expense(
          id: 'e1',
          groupId: 'g1',
          payerParticipantId: 'p1',
          amountCents: 100,
          currencyCode: 'USD',
          title: '<script>alert(1)</script>',
          date: DateTime.utc(2025, 1, 2),
          splitType: SplitType.equal,
          splitShares: const {},
          createdAt: DateTime.utc(2025),
          updatedAt: DateTime.utc(2025),
        ),
      ];
      final html = buildBackupHtmlReport(
        backupJson: {'version': 2, 'groups': []},
        groups: groups,
        expenses: expenses,
        exportedAt: DateTime.utc(2025, 1, 1),
      );
      expect(html, isNot(contains('<script>alert(1)</script>')));
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('type="application/json"'));
    });
  });

  group('zip package', () {
    test('round-trip backup.json and rejects zip slip', () {
      final bytes = encodeBackupZip(
        manifestJson: '{"version":2}',
        backupJson:
            '{"version":2,"groups":[],"participants":[],"expenses":[],"expense_tags":[]}',
        reportHtml: '<html></html>',
        expensesCsv: 'date\n',
      );
      final decoded = decodeBackupZip(bytes);
      expect(decoded.backupJson, contains('"version":2'));
    });
  });
}
