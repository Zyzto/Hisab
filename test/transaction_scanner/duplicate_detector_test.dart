import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/transaction_scanner/domain/draft_transaction.dart';
import 'package:hisab/features/transaction_scanner/services/duplicate_detector.dart';

DraftTransaction _draft({
  required String id,
  required int amountCents,
  required String currencyCode,
  required String senderPackage,
  required DateTime capturedAt,
  DraftStatus status = DraftStatus.pending,
}) {
  final now = DateTime(2026, 1, 1);
  return DraftTransaction(
    id: id,
    amountCents: amountCents,
    currencyCode: currencyCode,
    transactionDate: capturedAt,
    capturedAt: capturedAt,
    rawNotificationText: 'raw',
    senderPackage: senderPackage,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('DuplicateDetector.isDuplicate', () {
    final baseTime = DateTime(2026, 6, 1, 12, 0, 0);

    test('detects same sender+amount+currency within 60s', () {
      final existing = [
        _draft(
          id: 'a',
          amountCents: 1000,
          currencyCode: 'SAR',
          senderPackage: 'com.bank',
          capturedAt: baseTime,
        ),
      ];
      final candidate = _draft(
        id: 'b',
        amountCents: 1000,
        currencyCode: 'SAR',
        senderPackage: 'com.bank',
        capturedAt: baseTime.add(const Duration(seconds: 30)),
      );
      expect(DuplicateDetector.isDuplicate(candidate, existing), isTrue);
    });

    test('allows same amount outside the window', () {
      final existing = [
        _draft(
          id: 'a',
          amountCents: 1000,
          currencyCode: 'SAR',
          senderPackage: 'com.bank',
          capturedAt: baseTime,
        ),
      ];
      final candidate = _draft(
        id: 'b',
        amountCents: 1000,
        currencyCode: 'SAR',
        senderPackage: 'com.bank',
        capturedAt: baseTime.add(const Duration(seconds: 61)),
      );
      expect(DuplicateDetector.isDuplicate(candidate, existing), isFalse);
    });

    test('ignores existing rows already marked duplicate', () {
      final existing = [
        _draft(
          id: 'a',
          amountCents: 1000,
          currencyCode: 'SAR',
          senderPackage: 'com.bank',
          capturedAt: baseTime,
          status: DraftStatus.duplicate,
        ),
      ];
      final candidate = _draft(
        id: 'b',
        amountCents: 1000,
        currencyCode: 'SAR',
        senderPackage: 'com.bank',
        capturedAt: baseTime.add(const Duration(seconds: 5)),
      );
      expect(DuplicateDetector.isDuplicate(candidate, existing), isFalse);
    });

    test('requires matching currency and sender', () {
      final existing = [
        _draft(
          id: 'a',
          amountCents: 1000,
          currencyCode: 'SAR',
          senderPackage: 'com.bank',
          capturedAt: baseTime,
        ),
      ];
      expect(
        DuplicateDetector.isDuplicate(
          _draft(
            id: 'b',
            amountCents: 1000,
            currencyCode: 'USD',
            senderPackage: 'com.bank',
            capturedAt: baseTime,
          ),
          existing,
        ),
        isFalse,
      );
      expect(
        DuplicateDetector.isDuplicate(
          _draft(
            id: 'c',
            amountCents: 1000,
            currencyCode: 'SAR',
            senderPackage: 'com.other',
            capturedAt: baseTime,
          ),
          existing,
        ),
        isFalse,
      );
    });
  });
}
