import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/transaction_scanner/domain/draft_transaction.dart';

void main() {
  group('DraftStatus.fromString', () {
    test('parses known values', () {
      expect(DraftStatus.fromString('pending'), DraftStatus.pending);
      expect(DraftStatus.fromString('confirmed'), DraftStatus.confirmed);
      expect(DraftStatus.fromString('dismissed'), DraftStatus.dismissed);
      expect(DraftStatus.fromString('duplicate'), DraftStatus.duplicate);
    });

    test('falls back to pending for unknown values', () {
      expect(DraftStatus.fromString('nope'), DraftStatus.pending);
      expect(DraftStatus.fromString(''), DraftStatus.pending);
    });
  });

  group('DraftTransaction.displayTitle', () {
    final now = DateTime(2026, 1, 1);

    DraftTransaction draft({
      String? merchantName,
      String? senderTitle,
      String senderPackage = 'com.bank',
    }) {
      return DraftTransaction(
        id: '1',
        amountCents: 100,
        currencyCode: 'SAR',
        merchantName: merchantName,
        transactionDate: now,
        capturedAt: now,
        rawNotificationText: 'x',
        senderPackage: senderPackage,
        senderTitle: senderTitle,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('prefers merchant name', () {
      expect(
        draft(merchantName: 'Cafe', senderTitle: 'Bank').displayTitle,
        'Cafe',
      );
    });

    test('falls back to sender title then package', () {
      expect(draft(senderTitle: 'Bank Alerts').displayTitle, 'Bank Alerts');
      expect(draft().displayTitle, 'com.bank');
    });
  });
}
