import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/utils/expense_display_title.dart';
import 'package:hisab/domain/domain.dart';

Expense _expense({
  required String title,
  TransactionType type = TransactionType.expense,
  String payerId = 'from',
  String? toId,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Expense(
    id: 'e1',
    groupId: 'g1',
    payerParticipantId: payerId,
    amountCents: 1000,
    currencyCode: 'USD',
    title: title,
    date: now,
    splitType: SplitType.amounts,
    splitShares: {toId ?? payerId: 1000},
    createdAt: now,
    updatedAt: now,
    transactionType: type,
    toParticipantId: toId,
  );
}

ExpenseTitleTranslate _translateFrom(Map<String, String> strings) {
  return (key, {namedArgs}) {
    var value = strings[key] ?? key;
    if (namedArgs != null) {
      namedArgs.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> en;
  late Map<String, String> ar;

  setUpAll(() async {
    en = Map<String, String>.from(
      jsonDecode(await rootBundle.loadString('assets/translations/en.json'))
          as Map,
    );
    ar = Map<String, String>.from(
      jsonDecode(await rootBundle.loadString('assets/translations/ar.json'))
          as Map,
    );
  });

  test('non-transfer keeps stored title', () {
    expect(
      expenseDisplayTitle(
        _expense(title: 'Lunch'),
        fromName: 'Alice',
        toName: 'Bob',
        translate: _translateFrom(en),
      ),
      'Lunch',
    );
  });

  test('transfer uses EN settlement template from names', () {
    expect(
      expenseDisplayTitle(
        _expense(
          title: 'تصفية: Alice ← Bob',
          type: TransactionType.transfer,
          toId: 'to',
        ),
        fromName: 'Alice',
        toName: 'Bob',
        translate: _translateFrom(en),
      ),
      'Settlement: Alice → Bob',
    );
  });

  test('transfer uses AR settlement template from names', () {
    expect(
      expenseDisplayTitle(
        _expense(
          title: 'Settlement: Alice → Bob',
          type: TransactionType.transfer,
          toId: 'to',
        ),
        fromName: 'Alice',
        toName: 'Bob',
        translate: _translateFrom(ar),
      ),
      'تصفية: من Alice إلى Bob',
    );
  });

  test('EN and AR transfer titles differ', () {
    final expense = _expense(
      title: 'old',
      type: TransactionType.transfer,
      toId: 'to',
    );
    final enTitle = expenseDisplayTitle(
      expense,
      fromName: 'Alice',
      toName: 'Bob',
      translate: _translateFrom(en),
    );
    final arTitle = expenseDisplayTitle(
      expense,
      fromName: 'Alice',
      toName: 'Bob',
      translate: _translateFrom(ar),
    );
    expect(enTitle, isNot(equals(arTitle)));
  });

  test('transfer without names falls back to transfer label', () {
    expect(
      expenseDisplayTitle(
        _expense(
          title: 'Settlement: Alice → Bob',
          type: TransactionType.transfer,
          toId: 'to',
        ),
        translate: _translateFrom(en),
      ),
      'Transfer',
    );
  });

  test('expenseDisplayTitleFromMap resolves participant names', () {
    expect(
      expenseDisplayTitleFromMap(
        _expense(
          title: 'old',
          type: TransactionType.transfer,
          payerId: 'a',
          toId: 'b',
        ),
        {'a': 'Alice', 'b': 'Bob'},
        translate: _translateFrom(en),
      ),
      'Settlement: Alice → Bob',
    );
  });
}
