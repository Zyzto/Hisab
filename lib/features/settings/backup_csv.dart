import '../../domain/domain.dart';
import '../expenses/category_icons.dart';

/// Build a CSV of expenses for spreadsheet export (not importable).
String buildExpensesCsv({
  required List<Group> groups,
  required List<Participant> participants,
  required List<Expense> expenses,
  List<ExpenseTag> expenseTags = const [],
}) {
  final groupById = {for (final g in groups) g.id: g};
  final participantById = {for (final p in participants) p.id: p};
  final tagsByGroup = <String, List<ExpenseTag>>{};
  for (final t in expenseTags) {
    tagsByGroup.putIfAbsent(t.groupId, () => []).add(t);
  }

  final buf = StringBuffer();
  buf.writeln(
    'date,group,title,amount,currency,exchange_rate,base_amount,payer,split_type,tag,transaction_type,description',
  );
  final sorted = [...expenses]
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final e in sorted) {
    final g = groupById[e.groupId];
    final payer = participantById[e.payerParticipantId];
    final amount = (e.amountCents / 100).toStringAsFixed(2);
    final base = e.baseAmountCents != null
        ? (e.baseAmountCents! / 100).toStringAsFixed(2)
        : '';
    final tagLabel = exportDisplayTagLabel(
      e.tag,
      tagsByGroup[e.groupId] ?? const [],
    );
    buf.writeln(
      [
        e.date.toIso8601String(),
        _csvCell(g?.name ?? e.groupId),
        _csvCell(e.title),
        amount,
        e.currencyCode,
        e.exchangeRate.toString(),
        base,
        _csvCell(payer?.name ?? e.payerParticipantId),
        e.splitType.name,
        _csvCell(tagLabel),
        e.transactionType.name,
        _csvCell(e.description ?? ''),
      ].join(','),
    );
  }
  return buf.toString();
}

String _csvCell(String value) {
  var v = value.replaceAll('"', '""');
  // Mitigate CSV formula injection in Excel.
  if (v.isNotEmpty &&
      (v.startsWith('=') ||
          v.startsWith('+') ||
          v.startsWith('-') ||
          v.startsWith('@'))) {
    v = "'$v";
  }
  return '"$v"';
}
