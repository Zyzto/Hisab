import 'package:easy_localization/easy_localization.dart';

import '../../domain/domain.dart';

typedef ExpenseTitleTranslate =
    String Function(String key, {Map<String, String>? namedArgs});

String _defaultTranslate(String key, {Map<String, String>? namedArgs}) =>
    key.tr(namedArgs: namedArgs);

/// Localized display title for an expense.
///
/// Transfers rebuild from payer/payee names so the UI follows the current
/// locale instead of the language used when the row was saved. The stored
/// [Expense.title] remains a human string for push/activity feeds.
String expenseDisplayTitle(
  Expense expense, {
  String? fromName,
  String? toName,
  ExpenseTitleTranslate? translate,
}) {
  final t = translate ?? _defaultTranslate;
  if (expense.transactionType != TransactionType.transfer) {
    return expense.title;
  }

  final from = fromName?.trim();
  final to = toName?.trim();
  if (from != null &&
      from.isNotEmpty &&
      to != null &&
      to.isNotEmpty) {
    return t(
      'settlement_expense_title',
      namedArgs: {'from': from, 'to': to},
    );
  }
  return t('transfer');
}

/// Convenience when a participant id → name map is available.
String expenseDisplayTitleFromMap(
  Expense expense,
  Map<String, String> nameOf, {
  ExpenseTitleTranslate? translate,
}) {
  final toId = expense.toParticipantId;
  return expenseDisplayTitle(
    expense,
    fromName: nameOf[expense.payerParticipantId],
    toName: toId == null ? null : nameOf[toId],
    translate: translate,
  );
}
